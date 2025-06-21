// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./RWAToken.sol";
import "./interfaces/IRWAOrderbook.sol";

/**
 * @title RWAOrderbook
 * @notice Orderbook-based DEX for RWA tokens with native token pairing
 * @dev Supports bid/ask orders, only native token (ETH) pairing
 */
contract RWAOrderbook is IRWAOrderbook, ReentrancyGuard, Ownable, Pausable {

    // ---------------------------------------------------------------------
    // ░░ Structs & Storage ░░
    // ---------------------------------------------------------------------

    struct OrderBook {
        uint256[] buyOrderIds;
        uint256[] sellOrderIds;
        mapping(uint256 => Order) orders;
        uint256 nextOrderId;
    }

    /// @notice RWA token contract
    RWAToken public immutable rwaToken;

    /// @notice Order book for the RWA/ETH pair
    OrderBook public orderBook;

    /// @notice Mapping of user orders
    mapping(address => uint256[]) public userOrders;

    /// @notice Trading fee in basis points (100 = 1%)
    uint256 public tradingFee = 30; // 0.3%

    /// @notice Fee recipient
    address public feeRecipient;

    /// @notice Minimum order size
    uint256 public minOrderSize = 1e18; // 1 RWA token

    // ---------------------------------------------------------------------
    // ░░ Events ░░
    // ---------------------------------------------------------------------

    event OrderPlaced(
        uint256 indexed orderId,
        address indexed trader,
        bool indexed isBuyOrder,
        uint256 amount,
        uint256 price
    );

    event OrderFilled(
        uint256 indexed orderId,
        address indexed trader,
        address indexed counterparty,
        uint256 amount,
        uint256 price
    );

    event OrderCancelled(uint256 indexed orderId, address indexed trader);

    event Trade(
        address indexed buyer,
        address indexed seller,
        uint256 rwaAmount,
        uint256 ethAmount,
        uint256 price
    );

    event InitialLiquidityAdded(uint256 rwaAmount, uint256 ethAmount, uint256 price);

    // ---------------------------------------------------------------------
    // ░░ Constructor ░░
    // ---------------------------------------------------------------------

    constructor(
        address _rwaToken,
        address _feeRecipient,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_rwaToken != address(0), "Invalid RWA token");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        rwaToken = RWAToken(payable(_rwaToken));
        feeRecipient = _feeRecipient;
        orderBook.nextOrderId = 1;
    }

    // ---------------------------------------------------------------------
    // ░░ Initial Liquidity Setup ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Add initial liquidity by placing sell orders at specified price
     * @param price Price per RWA token in wei
     */
    function addInitialLiquidity(uint256 price) external onlyOwner {
        require(price > 0, "Price must be positive");
        
        uint256 rwaBalance = rwaToken.balanceOf(address(this));
        require(rwaBalance > 0, "No RWA tokens in contract");

        // Create a large sell order at the specified price
        _createOrder(address(this), rwaBalance, price, false);
        
        emit InitialLiquidityAdded(rwaBalance, rwaBalance * price / 1e18, price);
    }

    /**
     * @notice Get current RWA token balance in orderbook
     * @return Current RWA token balance
     */
    function getRWABalance() external view returns (uint256) {
        return rwaToken.balanceOf(address(this));
    }

    // ---------------------------------------------------------------------
    // ░░ Order Management ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Place a buy order (ETH for RWA tokens)
     * @param amount Amount of RWA tokens to buy
     * @param price Price per RWA token in wei
     */
    function placeBuyOrder(uint256 amount, uint256 price) external payable nonReentrant whenNotPaused {
        require(amount >= minOrderSize, "Order too small");
        require(price > 0, "Price must be positive");
        
        uint256 totalCost = (amount * price) / 1e18;
        require(msg.value >= totalCost, "Insufficient ETH");

        uint256 orderId = _createOrder(msg.sender, amount, price, true);
        
        // Only try to match if there are sell orders
        if (orderBook.sellOrderIds.length > 0) {
            _tryMatchOrder(orderId);
        }

        // Refund excess ETH
        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(success, "ETH refund failed");
        }
    }

    /**
     * @notice Place a sell order (RWA tokens for ETH)
     * @param amount Amount of RWA tokens to sell
     * @param price Price per RWA token in wei
     */
    function placeSellOrder(uint256 amount, uint256 price) external nonReentrant whenNotPaused {
        require(amount >= minOrderSize, "Order too small");
        require(price > 0, "Price must be positive");
        require(rwaToken.balanceOf(msg.sender) >= amount, "Insufficient RWA tokens");

        // Transfer RWA tokens to contract
        rwaToken.transferFrom(msg.sender, address(this), amount);

        uint256 orderId = _createOrder(msg.sender, amount, price, false);
        
        // Only try to match if there are buy orders
        if (orderBook.buyOrderIds.length > 0) {
            _tryMatchOrder(orderId);
        }
    }

    /**
     * @notice Cancel an active order
     * @param orderId Order ID to cancel
     */
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orderBook.orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        require(order.isActive, "Order not active");

        order.isActive = false;
        uint256 remaining = order.amount - order.filled;

        if (order.isBuyOrder) {
            // Refund ETH
            uint256 refundAmount = (remaining * order.price) / 1e18;
            if (refundAmount > 0) {
                (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
                require(success, "ETH refund failed");
            }
        } else {
            // Return RWA tokens
            if (remaining > 0) {
                rwaToken.transfer(msg.sender, remaining);
            }
        }

        _removeOrderFromBook(orderId);
        emit OrderCancelled(orderId, msg.sender);
    }

    // ---------------------------------------------------------------------
    // ░░ Internal Functions ░░
    // ---------------------------------------------------------------------

    function _createOrder(
        address trader,
        uint256 amount,
        uint256 price,
        bool isBuyOrder
    ) internal returns (uint256) {
        uint256 orderId = orderBook.nextOrderId++;
        
        orderBook.orders[orderId] = Order({
            id: orderId,
            trader: trader,
            amount: amount,
            price: price,
            isBuyOrder: isBuyOrder,
            isActive: true,
            filled: 0,
            timestamp: block.timestamp
        });

        if (isBuyOrder) {
            _insertBuyOrder(orderId);
        } else {
            _insertSellOrder(orderId);
        }

        userOrders[trader].push(orderId);
        
        emit OrderPlaced(orderId, trader, isBuyOrder, amount, price);
        return orderId;
    }

    function _tryMatchOrder(uint256 orderId) internal {
        Order storage order = orderBook.orders[orderId];
        
        if (order.isBuyOrder) {
            _matchBuyOrder(orderId);
        } else {
            _matchSellOrder(orderId);
        }
    }

    function _matchBuyOrder(uint256 buyOrderId) internal {
        Order storage buyOrder = orderBook.orders[buyOrderId];
        
        // Create a copy of sell order IDs to avoid modification during iteration
        uint256[] memory sellOrderIds = new uint256[](orderBook.sellOrderIds.length);
        for (uint i = 0; i < orderBook.sellOrderIds.length; i++) {
            sellOrderIds[i] = orderBook.sellOrderIds[i];
        }
        
        // Try to match with sell orders (lowest price first)
        for (uint i = 0; i < sellOrderIds.length && buyOrder.isActive; i++) {
            uint256 sellOrderId = sellOrderIds[i];
            Order storage sellOrder = orderBook.orders[sellOrderId];
            
            if (!sellOrder.isActive) continue;
            if (sellOrder.price > buyOrder.price) break; // No more matches possible
            
            _executeTrade(buyOrderId, sellOrderId);
        }
    }

    function _matchSellOrder(uint256 sellOrderId) internal {
        Order storage sellOrder = orderBook.orders[sellOrderId];
        
        // Create a copy of buy order IDs to avoid modification during iteration
        uint256[] memory buyOrderIds = new uint256[](orderBook.buyOrderIds.length);
        for (uint i = 0; i < orderBook.buyOrderIds.length; i++) {
            buyOrderIds[i] = orderBook.buyOrderIds[i];
        }
        
        // Try to match with buy orders (highest price first)
        for (uint i = 0; i < buyOrderIds.length && sellOrder.isActive; i++) {
            uint256 buyOrderId = buyOrderIds[i];
            Order storage buyOrder = orderBook.orders[buyOrderId];
            
            if (!buyOrder.isActive) continue;
            if (buyOrder.price < sellOrder.price) break; // No more matches possible
            
            _executeTrade(buyOrderId, sellOrderId);
        }
    }

    function _executeTrade(uint256 buyOrderId, uint256 sellOrderId) internal {
        Order storage buyOrder = orderBook.orders[buyOrderId];
        Order storage sellOrder = orderBook.orders[sellOrderId];
        
        uint256 tradeAmount = _min(
            buyOrder.amount - buyOrder.filled,
            sellOrder.amount - sellOrder.filled
        );
        
        if (tradeAmount == 0) return; // Nothing to trade
        
        uint256 tradePrice = sellOrder.price; // Sell order price takes precedence
        uint256 ethAmount = (tradeAmount * tradePrice) / 1e18;
        
        // Calculate fees
        uint256 fee = (ethAmount * tradingFee) / 10000;
        uint256 sellerAmount = ethAmount - fee;
        
        // Update order filled amounts
        buyOrder.filled += tradeAmount;
        sellOrder.filled += tradeAmount;
        
        // Transfer tokens - RWA tokens to buyer
        require(rwaToken.balanceOf(address(this)) >= tradeAmount, "Insufficient RWA tokens in contract");
        rwaToken.transfer(buyOrder.trader, tradeAmount);
        
        // Transfer ETH to seller
        if (sellerAmount > 0) {
            (bool successSeller, ) = payable(sellOrder.trader).call{value: sellerAmount}("");
            require(successSeller, "ETH transfer to seller failed");
        }
        
        // Transfer fee to fee recipient
        if (fee > 0) {
            (bool successFee, ) = payable(feeRecipient).call{value: fee}("");
            require(successFee, "Fee transfer failed");
        }
        
        // Check if orders are fully filled
        if (buyOrder.filled >= buyOrder.amount) {
            buyOrder.isActive = false;
            _removeOrderFromBook(buyOrderId);
        }
        
        if (sellOrder.filled >= sellOrder.amount) {
            sellOrder.isActive = false;
            _removeOrderFromBook(sellOrderId);
        }
        
        emit OrderFilled(buyOrderId, buyOrder.trader, sellOrder.trader, tradeAmount, tradePrice);
        emit OrderFilled(sellOrderId, sellOrder.trader, buyOrder.trader, tradeAmount, tradePrice);
        emit Trade(buyOrder.trader, sellOrder.trader, tradeAmount, ethAmount, tradePrice);
    }

    function _insertBuyOrder(uint256 orderId) internal {
        Order storage newOrder = orderBook.orders[orderId];
        uint256[] storage buyOrders = orderBook.buyOrderIds;
        
        // Insert in descending price order (highest first)
        uint256 insertIndex = buyOrders.length;
        for (uint i = 0; i < buyOrders.length; i++) {
            if (orderBook.orders[buyOrders[i]].price < newOrder.price) {
                insertIndex = i;
                break;
            }
        }
        
        buyOrders.push(0);
        for (uint i = buyOrders.length - 1; i > insertIndex; i--) {
            buyOrders[i] = buyOrders[i - 1];
        }
        buyOrders[insertIndex] = orderId;
    }

    function _insertSellOrder(uint256 orderId) internal {
        Order storage newOrder = orderBook.orders[orderId];
        uint256[] storage sellOrders = orderBook.sellOrderIds;
        
        // Insert in ascending price order (lowest first)
        uint256 insertIndex = sellOrders.length;
        for (uint i = 0; i < sellOrders.length; i++) {
            if (orderBook.orders[sellOrders[i]].price > newOrder.price) {
                insertIndex = i;
                break;
            }
        }
        
        sellOrders.push(0);
        for (uint i = sellOrders.length - 1; i > insertIndex; i--) {
            sellOrders[i] = sellOrders[i - 1];
        }
        sellOrders[insertIndex] = orderId;
    }

    function _removeOrderFromBook(uint256 orderId) internal {
        Order storage order = orderBook.orders[orderId];
        
        if (order.isBuyOrder) {
            _removeFromArray(orderBook.buyOrderIds, orderId);
        } else {
            _removeFromArray(orderBook.sellOrderIds, orderId);
        }
    }

    function _removeFromArray(uint256[] storage array, uint256 value) internal {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // ---------------------------------------------------------------------
    // ░░ View Functions ░░
    // ---------------------------------------------------------------------

    function getBuyOrders(uint256 limit) external view returns (Order[] memory) {
        uint256 count = _min(limit, orderBook.buyOrderIds.length);
        Order[] memory orders = new Order[](count);
        
        for (uint i = 0; i < count; i++) {
            orders[i] = orderBook.orders[orderBook.buyOrderIds[i]];
        }
        
        return orders;
    }

    function getSellOrders(uint256 limit) external view returns (Order[] memory) {
        uint256 count = _min(limit, orderBook.sellOrderIds.length);
        Order[] memory orders = new Order[](count);
        
        for (uint i = 0; i < count; i++) {
            orders[i] = orderBook.orders[orderBook.sellOrderIds[i]];
        }
        
        return orders;
    }

    function getUserOrders(address user) external view returns (Order[] memory) {
        uint256[] memory userOrderIds = userOrders[user];
        Order[] memory orders = new Order[](userOrderIds.length);
        
        for (uint i = 0; i < userOrderIds.length; i++) {
            orders[i] = orderBook.orders[userOrderIds[i]];
        }
        
        return orders;
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orderBook.orders[orderId];
    }

    function getBestBid() external view returns (uint256) {
        if (orderBook.buyOrderIds.length == 0) return 0;
        return orderBook.orders[orderBook.buyOrderIds[0]].price;
    }

    function getBestAsk() external view returns (uint256) {
        if (orderBook.sellOrderIds.length == 0) return 0;
        return orderBook.orders[orderBook.sellOrderIds[0]].price;
    }

    // ---------------------------------------------------------------------
    // ░░ Admin Functions ░░
    // ---------------------------------------------------------------------

    function setTradingFee(uint256 _tradingFee) external onlyOwner {
        require(_tradingFee <= 1000, "Fee too high"); // Max 10%
        tradingFee = _tradingFee;
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid recipient");
        feeRecipient = _feeRecipient;
    }

    function setMinOrderSize(uint256 _minOrderSize) external onlyOwner {
        minOrderSize = _minOrderSize;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency functions
    function emergencyWithdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @notice Withdraw RWA tokens from orderbook (project owner control)
     * @dev This allows project owners to manage their liquidity allocation
     */
    function withdrawRWATokens() external onlyOwner {
        uint256 balance = rwaToken.balanceOf(address(this));
        require(balance > 0, "No RWA tokens to withdraw");
        rwaToken.transfer(owner(), balance);
    }
    
    /**
     * @notice Emergency withdraw specific amount of RWA tokens
     * @param amount Amount of RWA tokens to withdraw
     */
    function withdrawRWATokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be positive");
        require(rwaToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        rwaToken.transfer(owner(), amount);
    }

    // Add receive function to accept ETH
    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RWAToken.sol";

/**
 * @title RWARFQ
 * @notice Request-for-Quote system for RWA token trading
 */
contract RWARFQ is ReentrancyGuard, Ownable {
    
    RWAToken public immutable rwaToken;
    
    struct Quote {
        address maker;
        bool isBuyQuote; // true = buying, false = selling
        uint256 amount;
        uint256 pricePerToken; // ETH per token
        uint256 expiry;
        bool isActive;
        string description;
    }
    
    Quote[] public quotes;
    mapping(address => uint256[]) public userQuotes;
    
    uint256 public maxQuoteDuration = 24 hours;
    uint256 public minQuoteAmount = 100 * 1e18;
    uint256 public tradingFee = 50; // 0.5%
    address public feeRecipient;
    
    event QuoteSubmitted(
        uint256 indexed quoteId,
        address indexed maker,
        bool isBuyQuote,
        uint256 amount,
        uint256 pricePerToken,
        uint256 expiry
    );
    
    event QuoteAccepted(
        uint256 indexed quoteId,
        address indexed taker,
        uint256 amount,
        uint256 totalPrice
    );
    
    event QuoteCancelled(uint256 indexed quoteId, address indexed maker);
    
    error QuoteNotActive();
    error QuoteExpired();
    error InsufficientAmount();
    error InsufficientPayment();
    error NotQuoteMaker();
    error InvalidQuote();
    
    constructor(
        address _rwaToken,
        address _feeRecipient,
        address _owner
    ) Ownable(_owner) {
        rwaToken = RWAToken(_rwaToken);
        feeRecipient = _feeRecipient;
    }
    
    function submitQuote(
        bool isBuyQuote,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        string memory description
    ) external payable {
        if (amount < minQuoteAmount) revert InsufficientAmount();
        if (duration > maxQuoteDuration) duration = maxQuoteDuration;
        
        uint256 expiry = block.timestamp + duration;
        
        if (isBuyQuote) {
            uint256 totalCost = (amount * pricePerToken) / 1e18;
            if (msg.value < totalCost) revert InsufficientPayment();
        } else {
            rwaToken.transferFrom(msg.sender, address(this), amount);
        }
        
        quotes.push(Quote({
            maker: msg.sender,
            isBuyQuote: isBuyQuote,
            amount: amount,
            pricePerToken: pricePerToken,
            expiry: expiry,
            isActive: true,
            description: description
        }));
        
        uint256 quoteId = quotes.length - 1;
        userQuotes[msg.sender].push(quoteId);
        
        emit QuoteSubmitted(quoteId, msg.sender, isBuyQuote, amount, pricePerToken, expiry);
    }
    
    function acceptQuote(uint256 quoteId) external payable nonReentrant {
        Quote storage quote = quotes[quoteId];
        
        if (!quote.isActive) revert QuoteNotActive();
        if (block.timestamp > quote.expiry) revert QuoteExpired();
        
        uint256 totalPrice = (quote.amount * quote.pricePerToken) / 1e18;
        uint256 fee = (totalPrice * tradingFee) / 10000;
        
        if (quote.isBuyQuote) {
            // Maker wants to buy, taker is selling
            rwaToken.transferFrom(msg.sender, quote.maker, quote.amount);
            
            uint256 sellerAmount = totalPrice - fee;
            payable(msg.sender).transfer(sellerAmount);
            
            // Refund any excess ETH to quote maker
            uint256 excess = address(this).balance - fee;
            if (excess > 0) {
                payable(quote.maker).transfer(excess);
            }
        } else {
            // Maker wants to sell, taker is buying
            if (msg.value < totalPrice) revert InsufficientPayment();
            
            rwaToken.transfer(msg.sender, quote.amount);
            
            uint256 sellerAmount = totalPrice - fee;
            payable(quote.maker).transfer(sellerAmount);
            
            // Refund excess ETH to taker
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
        }
        
        // Transfer fee
        if (fee > 0) {
            payable(feeRecipient).transfer(fee);
        }
        
        quote.isActive = false;
        
        emit QuoteAccepted(quoteId, msg.sender, quote.amount, totalPrice);
    }
    
    function cancelQuote(uint256 quoteId) external {
        Quote storage quote = quotes[quoteId];
        
        if (quote.maker != msg.sender) revert NotQuoteMaker();
        if (!quote.isActive) revert QuoteNotActive();
        
        quote.isActive = false;
        
        if (quote.isBuyQuote) {
            // Refund ETH to buyer
            uint256 totalCost = (quote.amount * quote.pricePerToken) / 1e18;
            payable(quote.maker).transfer(totalCost);
        } else {
            // Return tokens to seller
            rwaToken.transfer(quote.maker, quote.amount);
        }
        
        emit QuoteCancelled(quoteId, msg.sender);
    }
    
    function getActiveQuotes(bool isBuyQuote) external view returns (
        uint256[] memory quoteIds,
        Quote[] memory activeQuotes
    ) {
        uint256 count = 0;
        
        // Count active quotes
        for (uint256 i = 0; i < quotes.length; i++) {
            if (quotes[i].isActive && 
                quotes[i].isBuyQuote == isBuyQuote && 
                block.timestamp <= quotes[i].expiry) {
                count++;
            }
        }
        
        quoteIds = new uint256[](count);
        activeQuotes = new Quote[](count);
        
        uint256 index = 0;
        for (uint256 i = 0; i < quotes.length; i++) {
            if (quotes[i].isActive && 
                quotes[i].isBuyQuote == isBuyQuote && 
                block.timestamp <= quotes[i].expiry) {
                quoteIds[index] = i;
                activeQuotes[index] = quotes[i];
                index++;
            }
        }
    }
    
    function getUserQuotes(address user) external view returns (uint256[] memory) {
        return userQuotes[user];
    }
    
    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        tradingFee = newFee;
    }
    
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }
    
    function updateConfig(uint256 newMaxDuration, uint256 newMinAmount) external onlyOwner {
        maxQuoteDuration = newMaxDuration;
        minQuoteAmount = newMinAmount;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWAOrderbook
 * @notice Interface for RWA orderbook contracts
 */
interface IRWAOrderbook {
    struct Order {
        uint256 id;
        address trader;
        uint256 amount;
        uint256 price;
        bool isBuyOrder;
        bool isActive;
        uint256 filled;
        uint256 timestamp;
    }

    function placeBuyOrder(uint256 amount, uint256 price) external payable;
    function placeSellOrder(uint256 amount, uint256 price) external;
    function cancelOrder(uint256 orderId) external;
    function getBuyOrders(uint256 limit) external view returns (Order[] memory);
    function getSellOrders(uint256 limit) external view returns (Order[] memory);
    function getBestBid() external view returns (uint256);
    function getBestAsk() external view returns (uint256);
}
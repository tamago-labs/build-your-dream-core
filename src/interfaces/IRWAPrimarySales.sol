// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWAPrimarySales {
    
    // Purchase functions
    function purchaseTokens() external payable;
    
    // Management functions
    function whitelistUsers(address[] calldata users, bool status) external;
    function updatePrice(uint256 newPrice) external;
    function updateLimits(uint256 newMin, uint256 newMax) external;
    function updateTreasury(address newTreasury) external;
    
    // View functions
    function getTokensForETH(uint256 ethAmount) external view returns (uint256);
    function getETHForTokens(uint256 tokenAmount) external view returns (uint256);
    
    // Configuration getters
    function totalAllocation() external view returns (uint256);
    function totalSold() external view returns (uint256);
    function pricePerTokenETH() external view returns (uint256);
    function minPurchase() external view returns (uint256);
    function maxPurchase() external view returns (uint256);
    function whitelisted(address user) external view returns (bool);
    function purchased(address user) external view returns (uint256);
    function treasury() external view returns (address);
    
    // Events
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event PriceUpdated(uint256 newPrice);
    event UserWhitelisted(address indexed user, bool status);
}
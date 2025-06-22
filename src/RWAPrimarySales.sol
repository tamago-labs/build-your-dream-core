// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./RWAToken.sol";

/**
 * @title RWAPrimarySales
 * @notice Primary distribution contract for RWA tokens
 */
contract RWAPrimarySales is ReentrancyGuard, Ownable, Pausable {
    
    RWAToken public immutable rwaToken;
    
    uint256 public totalAllocation;
    uint256 public totalSold;
    uint256 public pricePerTokenETH; // Price in ETH (18 decimals)
    uint256 public minPurchase = 1 ether; // Minimum 1 ETH worth
    uint256 public maxPurchase = 100 ether; // Maximum 100 ETH worth
    
    mapping(address => bool) public whitelisted;
    mapping(address => uint256) public purchased; // Amount purchased in ETH
    
    address public treasury;
    
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event PriceUpdated(uint256 newPrice);
    event UserWhitelisted(address indexed user, bool status);
    
    error NotWhitelisted();
    error InsufficientAllocation();
    error BelowMinimumPurchase();
    error ExceedsMaximumPurchase();
    error InsufficientPayment();
    error InvalidPrice();
    
    constructor(
        address _rwaToken,
        address _treasury,
        uint256 _totalAllocation,
        uint256 _pricePerTokenETH,
        address _owner
    ) Ownable(_owner) {
        rwaToken = RWAToken(_rwaToken);
        treasury = _treasury;
        totalAllocation = _totalAllocation;
        pricePerTokenETH = _pricePerTokenETH;
    }
    
    function purchaseTokens() external payable nonReentrant whenNotPaused {
        if (!whitelisted[msg.sender]) revert NotWhitelisted();
        if (msg.value < minPurchase) revert BelowMinimumPurchase();
        if (purchased[msg.sender] + msg.value > maxPurchase) revert ExceedsMaximumPurchase();
        
        uint256 tokenAmount = (msg.value * 1e18) / pricePerTokenETH;
        
        if (totalSold + tokenAmount > totalAllocation) revert InsufficientAllocation();
        
        totalSold += tokenAmount;
        purchased[msg.sender] += msg.value;
        
        rwaToken.transfer(msg.sender, tokenAmount);
        payable(treasury).transfer(msg.value);
        
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }
    
    function whitelistUsers(address[] calldata users, bool status) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelisted[users[i]] = status;
            emit UserWhitelisted(users[i], status);
        }
    }
    
    function updatePrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidPrice();
        pricePerTokenETH = newPrice;
        emit PriceUpdated(newPrice);
    }
    
    function updateLimits(uint256 newMin, uint256 newMax) external onlyOwner {
        require(newMin <= newMax, "Invalid limits");
        minPurchase = newMin;
        maxPurchase = newMax;
    }
    
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        treasury = newTreasury;
    }
    
    function getTokensForETH(uint256 ethAmount) external view returns (uint256) {
        return (ethAmount * 1e18) / pricePerTokenETH;
    }
    
    function getETHForTokens(uint256 tokenAmount) external view returns (uint256) {
        return (tokenAmount * pricePerTokenETH) / 1e18;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        rwaToken.transfer(owner(), amount);
    }
}
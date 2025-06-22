// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWARFQ {
    
    struct Quote {
        address maker;
        bool isBuyQuote;
        uint256 amount;
        uint256 pricePerToken;
        uint256 expiry;
        bool isActive;
        string description;
    }
    
    // Quote functions
    function submitQuote(
        bool isBuyQuote,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        string memory description
    ) external payable;
    
    function acceptQuote(uint256 quoteId) external payable;
    function cancelQuote(uint256 quoteId) external;
    
    // View functions
    function getActiveQuotes(bool isBuyQuote) external view returns (uint256[] memory, Quote[] memory);
    function getUserQuotes(address user) external view returns (uint256[] memory);
    function quotes(uint256 quoteId) external view returns (Quote memory);
    
    // Configuration
    function updateFee(uint256 newFee) external;
    function updateFeeRecipient(address newRecipient) external;
    function updateConfig(uint256 newMaxDuration, uint256 newMinAmount) external;
    
    // Configuration getters
    function maxQuoteDuration() external view returns (uint256);
    function minQuoteAmount() external view returns (uint256);
    function tradingFee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    
    // Events
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
}
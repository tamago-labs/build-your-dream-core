// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWA {
    
    struct AssetMetadata {
        string assetType;
        string description;
        uint256 totalValue;
        string url;
        uint256 createdAt;
    }
    
    // Core functions
    function assetData() external view returns (AssetMetadata memory);
    function projectWallet() external view returns (address);
    function projectAllocationPercent() external view returns (uint256);
    function initialLiquidityTokens() external view returns (uint256);
    function authorized(address account) external view returns (bool);
    
    // Management functions
    function updateAssetMetadata(AssetMetadata memory newMetadata) external;
    function updateProjectWallet(address newProjectWallet) external;
    function setAuthorized(address account, bool auth) external;
    function transferLiquidityTokens(address to, uint256 amount) external;
    
    // View functions
    function getAvailableLiquidityTokens() external view returns (uint256);
    function getInitialLiquidityAllocation() external view returns (uint256);
    function getPricePerToken() external view returns (uint256);
    function getMarketCap() external view returns (uint256);
    function getAllocationDetails() external view returns (uint256, uint256, uint256);
    function isAuthorized(address account) external view returns (bool);
    
    // Events
    event AssetMetadataUpdated(string assetType, string description, uint256 totalValue, string url);
    event ProjectWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event AuthorizedUpdated(address indexed account, bool authorized);
    event LiquidityTokensTransferred(address indexed to, uint256 amount);
}
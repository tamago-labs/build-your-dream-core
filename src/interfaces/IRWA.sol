// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWA
 * @notice Interface for RWA token contracts
 */
interface IRWA {
    struct AssetMetadata {
        string assetType;
        string description;
        uint256 totalValue;
        string url;
        uint256 createdAt;
    }
 
    function assetData() external view returns (AssetMetadata memory);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWAFactory {
    
    struct AssetMetadata {
        string assetType;
        string description;
        uint256 totalValue;
        string url;
        uint256 createdAt;
    }
    
    struct RWAProject {
        address rwaToken;
        address primarySales;
        address rfq;
        address vault;
        address creator;
        bool isActive;
        uint256 createdAt;
    }
    
    // Project creation
    function createRWAProject(
        string memory name,
        string memory symbol,
        AssetMetadata memory metadata,
        address projectWallet,
        uint256 projectAllocationPercent,
        uint256 pricePerTokenETH
    ) external payable returns (uint256 projectId);
    
    // View functions
    function getProject(uint256 projectId) external view returns (RWAProject memory);
    function getCreatorProjects(address creator) external view returns (uint256[] memory);
    
    // Management
    function updateCreationFee(uint256 newFee) external;
    function updateAddresses(address newFeeRecipient, address newTreasury) external;
    function deactivateProject(uint256 projectId) external;
    
    // Configuration getters
    function projects(uint256 projectId) external view returns (RWAProject memory);
    function creatorProjects(address creator, uint256 index) external view returns (uint256);
    function nextProjectId() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function treasury() external view returns (address);
    function creationFee() external view returns (uint256);
    
    // Events
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        address rwaToken,
        address primarySales,
        address rfq,
        address vault,
        string name,
        string symbol
    );
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RWAToken.sol";
import "./RWAPrimarySales.sol";
import "./RWARFQ.sol";
import "./RWAVault.sol";

/**
 * @title RWAFactory
 * @notice Factory for creating complete RWA token ecosystems
 */
contract RWAFactory is Ownable {
    
    struct RWAProject {
        address rwaToken;
        address primarySales;
        address rfq;
        address vault;
        address creator;
        bool isActive;
        uint256 createdAt;
    }
    
    mapping(uint256 => RWAProject) public projects;
    mapping(address => uint256[]) public creatorProjects;
    uint256 public nextProjectId = 1;
    
    address public feeRecipient;
    address public treasury;
    uint256 public creationFee = 0.1 ether;
    
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
    
    constructor(address _feeRecipient, address _treasury, address _owner) Ownable(_owner) {
        feeRecipient = _feeRecipient;
        treasury = _treasury;
    }
    
    function createRWAProject(
        string memory name,
        string memory symbol,
        RWAToken.AssetMetadata memory metadata,
        address projectWallet,
        uint256 projectAllocationPercent,
        uint256 pricePerTokenETH
    ) external payable returns (uint256 projectId) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");
        require(projectWallet != address(0), "Invalid project wallet");
        require(pricePerTokenETH > 0, "Price required");
        
        projectId = nextProjectId++;
        
        // Deploy RWA Token (Factory is initial owner)
        RWAToken rwaToken = new RWAToken(
            name,
            symbol,
            metadata,
            projectWallet,
            projectAllocationPercent,
            address(this) // Factory is initial owner
        );
        
        // Calculate allocations
        uint256 totalSupply = 1_000_000_000 * 10**18;
        uint256 projectTokens = (totalSupply * projectAllocationPercent) / 100;
        uint256 salesAllocation = totalSupply - projectTokens;
        
        // Deploy Primary Sales
        RWAPrimarySales primarySales = new RWAPrimarySales(
            address(rwaToken),
            treasury,
            salesAllocation,
            pricePerTokenETH,
            msg.sender
        );
        
        // Deploy RFQ
        RWARFQ rfq = new RWARFQ(
            address(rwaToken),
            feeRecipient,
            msg.sender
        );
        
        // Deploy Vault
        RWAVault vault = new RWAVault(
            address(rwaToken),
            msg.sender
        );
        
        // Authorize primary sales contract to receive tokens
        rwaToken.setAuthorized(address(primarySales), true);
        
        // Transfer sales allocation to primary sales contract
        rwaToken.transferLiquidityTokens(address(primarySales), salesAllocation);
        
        // Transfer ownership to project creator
        rwaToken.transferOwnership(msg.sender);
        
        // Store project
        projects[projectId] = RWAProject({
            rwaToken: address(rwaToken),
            primarySales: address(primarySales),
            rfq: address(rfq),
            vault: address(vault),
            creator: msg.sender,
            isActive: true,
            createdAt: block.timestamp
        });
        
        creatorProjects[msg.sender].push(projectId);
        
        // Transfer creation fee
        if (msg.value > 0) {
            payable(treasury).transfer(msg.value);
        }
        
        emit ProjectCreated(
            projectId,
            msg.sender,
            address(rwaToken),
            address(primarySales),
            address(rfq),
            address(vault),
            name,
            symbol
        );
    }
    
    function getProject(uint256 projectId) external view returns (RWAProject memory) {
        return projects[projectId];
    }
    
    function getCreatorProjects(address creator) external view returns (uint256[] memory) {
        return creatorProjects[creator];
    }
    
    function updateCreationFee(uint256 newFee) external onlyOwner {
        creationFee = newFee;
    }
    
    function updateAddresses(address newFeeRecipient, address newTreasury) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid fee recipient");
        require(newTreasury != address(0), "Invalid treasury");
        feeRecipient = newFeeRecipient;
        treasury = newTreasury;
    }
    
    function deactivateProject(uint256 projectId) external onlyOwner {
        projects[projectId].isActive = false;
    }
}
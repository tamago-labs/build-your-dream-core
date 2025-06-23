// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./factories/RWATokenFactory.sol";
import "./factories/RWATradingFactory.sol";
import "./factories/RWAVaultFactory.sol";
import "./RWAToken.sol";

/**
 * @title RWACoordinator
 * @notice Main coordinator that orchestrates all specialized factories to create complete RWA ecosystems
 * @dev This modular approach keeps individual contracts small while maintaining full functionality
 */
contract RWACoordinator is Ownable {
    
    // Specialized factories
    RWATokenFactory public immutable tokenFactory;
    RWATradingFactory public immutable tradingFactory;
    RWAVaultFactory public immutable vaultFactory;
    
    // Project management
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
    
    // Configuration
    address public feeRecipient;
    address public treasury;
    
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
    
    event FactoryUpdated(string factoryType, address oldFactory, address newFactory);
    
    constructor(
        address _tokenFactory,
        address _tradingFactory,
        address _vaultFactory,
        address _feeRecipient,
        address _treasury,
        address _owner
    ) Ownable(_owner) {
        require(_tokenFactory != address(0), "Invalid token factory");
        require(_tradingFactory != address(0), "Invalid trading factory");
        require(_vaultFactory != address(0), "Invalid vault factory");
        require(_feeRecipient != address(0), "Invalid fee recipient");
        require(_treasury != address(0), "Invalid treasury");
        
        tokenFactory = RWATokenFactory(_tokenFactory);
        tradingFactory = RWATradingFactory(_tradingFactory);
        vaultFactory = RWAVaultFactory(_vaultFactory);
        feeRecipient = _feeRecipient;
        treasury = _treasury;
    }
    
    /**
     * @notice Create a complete RWA project using modular factories
     * @param name Token name
     * @param symbol Token symbol
     * @param metadata Asset metadata
     * @param projectWallet Project treasury wallet
     * @param projectAllocationPercent Percentage allocated to project (0-100)
     * @param pricePerTokenETH Price per token in ETH for primary sales
     * @return projectId ID of the created project
     */
    function createRWAProject(
        string memory name,
        string memory symbol,
        RWAToken.AssetMetadata memory metadata,
        address projectWallet,
        uint256 projectAllocationPercent,
        uint256 pricePerTokenETH
    ) external returns (uint256 projectId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");
        require(projectWallet != address(0), "Invalid project wallet");
        require(pricePerTokenETH > 0, "Price required");
        require(projectAllocationPercent <= 100, "Invalid allocation");
        
        projectId = nextProjectId++;
        
        // Step 1: Create token using TokenFactory
        address tokenAddress = tokenFactory.createToken(
            projectId,
            name,
            symbol,
            metadata,
            projectWallet,
            projectAllocationPercent,
            address(this) // Coordinator will be initial owner
        );
        
        // Calculate allocations
        uint256 totalSupply = 1_000_000_000 * 10**18;
        uint256 projectTokens = (totalSupply * projectAllocationPercent) / 100;
        uint256 salesAllocation = totalSupply - projectTokens;
        
        // Step 2: Create trading contracts using TradingFactory
        (address primarySalesAddress, address rfqAddress) = tradingFactory.createTradingContracts(
            projectId,
            tokenAddress,
            treasury,
            feeRecipient,
            salesAllocation,
            pricePerTokenETH,
            msg.sender
        );
        
        // Step 3: Create vault using VaultFactory
        address vaultAddress = vaultFactory.createVault(
            projectId,
            tokenAddress,
            msg.sender
        );
        
        // Step 4: Configure token and transfer ownership
        RWAToken token = RWAToken(tokenAddress);
        
        // Authorize primary sales contract to receive tokens
        token.setAuthorized(primarySalesAddress, true);
        
        // Transfer sales allocation to primary sales contract
        token.transferLiquidityTokens(primarySalesAddress, salesAllocation);
        
        // Transfer token ownership to project creator
        token.transferOwnership(msg.sender);
        
        // Step 5: Store project information
        projects[projectId] = RWAProject({
            rwaToken: tokenAddress,
            primarySales: primarySalesAddress,
            rfq: rfqAddress,
            vault: vaultAddress,
            creator: msg.sender,
            isActive: true,
            createdAt: block.timestamp
        });
        
        creatorProjects[msg.sender].push(projectId);
        
        emit ProjectCreated(
            projectId,
            msg.sender,
            tokenAddress,
            primarySalesAddress,
            rfqAddress,
            vaultAddress,
            name,
            symbol
        );
    }
    
    /**
     * @notice Get project details
     * @param projectId Project ID
     * @return project Project information
     */
    function getProject(uint256 projectId) external view returns (RWAProject memory project) {
        return projects[projectId];
    }
    
    /**
     * @notice Get projects created by a specific address
     * @param creator Creator address
     * @return projectIds Array of project IDs
     */
    function getCreatorProjects(address creator) external view returns (uint256[] memory projectIds) {
        return creatorProjects[creator];
    }
    
    /**
     * @notice Get factory addresses
     * @return tokenFactoryAddr Token factory address
     * @return tradingFactoryAddr Trading factory address
     * @return vaultFactoryAddr Vault factory address
     */
    function getFactories() external view returns (
        address tokenFactoryAddr,
        address tradingFactoryAddr,
        address vaultFactoryAddr
    ) {
        return (
            address(tokenFactory),
            address(tradingFactory),
            address(vaultFactory)
        );
    }
    
    /**
     * @notice Get coordinator configuration
     * @return feeRecipientAddr Fee recipient address
     * @return treasuryAddr Treasury address
     * @return nextId Next project ID
     */
    function getConfiguration() external view returns (
        address feeRecipientAddr,
        address treasuryAddr,
        uint256 nextId
    ) {
        return (feeRecipient, treasury, nextProjectId);
    }
    
    /**
     * @notice Update fee recipient and treasury (owner only)
     * @param newFeeRecipient New fee recipient address
     * @param newTreasury New treasury address
     */
    function updateAddresses(address newFeeRecipient, address newTreasury) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid fee recipient");
        require(newTreasury != address(0), "Invalid treasury");
        
        feeRecipient = newFeeRecipient;
        treasury = newTreasury;
    }
    
    /**
     * @notice Deactivate a project (owner only)
     * @param projectId Project ID to deactivate
     */
    function deactivateProject(uint256 projectId) external onlyOwner {
        require(projects[projectId].creator != address(0), "Project not found");
        projects[projectId].isActive = false;
    }
    
    /**
     * @notice Get project count and statistics
     * @return totalProjects Total number of projects created
     * @return activeProjects Number of active projects
     */
    function getProjectStats() external view returns (uint256 totalProjects, uint256 activeProjects) {
        totalProjects = nextProjectId - 1;
        
        for (uint256 i = 1; i < nextProjectId; i++) {
            if (projects[i].isActive) {
                activeProjects++;
            }
        }
    }
}

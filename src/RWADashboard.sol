// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RWAFactory.sol";
import "./RWAToken.sol";
import "./RWAPrimarySales.sol";
import "./RWARFQ.sol";
import "./RWAVault.sol";

/**
 * @title RWADashboard
 * @notice Centralized dashboard for managing and viewing RWA projects
 */
contract RWADashboard {
    
    RWAFactory public immutable factory;
    
    struct ProjectOverview {
        uint256 projectId;
        string name;
        string symbol;
        address creator;
        bool isActive;
        uint256 createdAt;
        
        // Token info
        uint256 totalSupply;
        uint256 marketCap;
        uint256 pricePerToken;
        string assetType;
        
        // Sales info
        uint256 totalAllocation;
        uint256 totalSold;
        uint256 salesPriceETH;
        
        // Vault info
        uint256 totalStaked;
        uint256 totalRewardsDistributed;
        
        // RFQ info
        uint256 activeQuotesCount;
    }
    
    struct UserProjectData {
        // Token holdings
        uint256 tokenBalance;
        
        // Primary sales
        uint256 purchasedAmount;
        bool isWhitelisted;
        
        // Vault
        uint256 stakedAmount;
        uint256 pendingRewards;
        uint256 stakedAt;
        
        // RFQ
        uint256[] userQuotes;
    }
    
    constructor(address _factory) {
        factory = RWAFactory(_factory);
    }
    
    /**
     * @notice Get comprehensive overview of a project
     */
    function getProjectOverview(uint256 projectId) external view returns (ProjectOverview memory overview) {
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        overview.projectId = projectId;
        overview.creator = project.creator;
        overview.isActive = project.isActive;
        overview.createdAt = project.createdAt;
        
        if (project.rwaToken != address(0)) {
            RWAToken rwaToken = RWAToken(project.rwaToken);
            
            // Token info
            overview.totalSupply = rwaToken.totalSupply();
            overview.marketCap = rwaToken.getMarketCap();
            overview.pricePerToken = rwaToken.getPricePerToken();
            
            // Get asset metadata components
            (string memory assetType, string memory description, uint256 totalValue, string memory url, uint256 createdAt) = rwaToken.assetData();
            overview.assetType = assetType;
            overview.name = rwaToken.name();
            overview.symbol = rwaToken.symbol();
        }
        
        if (project.primarySales != address(0)) {
            RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
            
            overview.totalAllocation = sales.totalAllocation();
            overview.totalSold = sales.totalSold();
            overview.salesPriceETH = sales.pricePerTokenETH();
        }
        
        if (project.vault != address(0)) {
            RWAVault vault = RWAVault(payable(project.vault));
            
            (uint256 totalStaked, uint256 totalRewards,,) = vault.getVaultStats();
            overview.totalStaked = totalStaked;
            overview.totalRewardsDistributed = totalRewards;
        }
        
        if (project.rfq != address(0)) {
            RWARFQ rfq = RWARFQ(project.rfq);
            
            // Count active quotes (simplified - just buy quotes for now)
            (uint256[] memory quoteIds,) = rfq.getActiveQuotes(true);
            overview.activeQuotesCount = quoteIds.length;
        }
    }
    
    /**
     * @notice Get user-specific data for a project
     */
    function getUserProjectData(uint256 projectId, address user) external view returns (UserProjectData memory data) {
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        if (project.rwaToken != address(0)) {
            RWAToken rwaToken = RWAToken(project.rwaToken);
            data.tokenBalance = rwaToken.balanceOf(user);
        }
        
        if (project.primarySales != address(0)) {
            RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
            data.purchasedAmount = sales.purchased(user);
            data.isWhitelisted = sales.whitelisted(user);
        }
        
        if (project.vault != address(0)) {
            RWAVault vault = RWAVault(payable(project.vault));
            (data.stakedAmount, data.pendingRewards, data.stakedAt) = vault.getUserStakeInfo(user);
        }
        
        if (project.rfq != address(0)) {
            RWARFQ rfq = RWARFQ(project.rfq);
            data.userQuotes = rfq.getUserQuotes(user);
        }
    }
    
    /**
     * @notice Get multiple project overviews
     */
    function getMultipleProjectOverviews(uint256[] calldata projectIds) external view returns (ProjectOverview[] memory overviews) {
        overviews = new ProjectOverview[](projectIds.length);
        
        for (uint256 i = 0; i < projectIds.length; i++) {
            overviews[i] = this.getProjectOverview(projectIds[i]);
        }
    }
    
    /**
     * @notice Get all projects created by a user
     */
    function getCreatorProjectOverviews(address creator) external view returns (ProjectOverview[] memory overviews) {
        uint256[] memory projectIds = factory.getCreatorProjects(creator);
        overviews = new ProjectOverview[](projectIds.length);
        
        for (uint256 i = 0; i < projectIds.length; i++) {
            overviews[i] = this.getProjectOverview(projectIds[i]);
        }
    }
    
    /**
     * @notice Get project addresses
     */
    function getProjectAddresses(uint256 projectId) external view returns (
        address rwaToken,
        address primarySales,
        address rfq,
        address vault
    ) {
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        return (
            project.rwaToken,
            project.primarySales,
            project.rfq,
            project.vault
        );
    }
    
    /**
     * @notice Get factory statistics
     */
    function getFactoryStats() external view returns (
        uint256 totalProjects,
        uint256 creationFee,
        address feeRecipient,
        address treasury
    ) {
        totalProjects = factory.nextProjectId() - 1;
        creationFee = factory.creationFee();
        feeRecipient = factory.feeRecipient();
        treasury = factory.treasury();
    }
    
    /**
     * @notice Check if user can purchase tokens
     */
    function canUserPurchase(uint256 projectId, address user, uint256 ethAmount) external view returns (
        bool canPurchase,
        string memory reason
    ) {
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        if (project.primarySales == address(0)) {
            return (false, "No primary sales contract");
        }
        
        RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
        
        if (!sales.whitelisted(user)) {
            return (false, "User not whitelisted");
        }
        
        if (ethAmount < sales.minPurchase()) {
            return (false, "Below minimum purchase");
        }
        
        if (sales.purchased(user) + ethAmount > sales.maxPurchase()) {
            return (false, "Exceeds maximum purchase");
        }
        
        uint256 tokenAmount = sales.getTokensForETH(ethAmount);
        if (sales.totalSold() + tokenAmount > sales.totalAllocation()) {
            return (false, "Insufficient allocation");
        }
        
        return (true, "");
    }
    
    /**
     * @notice Get market activity for RFQ
     */
    function getMarketActivity(uint256 projectId) external view returns (
        uint256[] memory buyQuoteIds,
        RWARFQ.Quote[] memory buyQuotes,
        uint256[] memory sellQuoteIds,
        RWARFQ.Quote[] memory sellQuotes
    ) {
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        if (project.rfq != address(0)) {
            RWARFQ rfq = RWARFQ(project.rfq);
            
            (buyQuoteIds, buyQuotes) = rfq.getActiveQuotes(true);
            (sellQuoteIds, sellQuotes) = rfq.getActiveQuotes(false);
        }
    }
}
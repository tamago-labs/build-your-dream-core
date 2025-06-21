// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title RWAToken
 * @notice Real World Asset (RWA) token with built-in liquidity allocation
 * @dev ERC20 token representing fractional ownership of real-world assets
 */
contract RWAToken is ERC20, ERC20Permit, Ownable, ReentrancyGuard, Pausable {
    
    // ============ Structs ============
    
    struct AssetMetadata {
        string assetType;        // "real-estate", "commodity", "art", "intellectual-property"
        string description;      // Detailed description of the asset
        uint256 totalValue;      // Total appraised value in USD (with 8 decimals)
        string url;              // URL to asset documentation/images
        uint256 createdAt;       // Creation timestamp
    }

    // ============ State Variables ============
    
    /// @notice Asset metadata
    AssetMetadata public assetData;
    
    /// @notice Project treasury wallet (receives project allocation)
    address public projectWallet;
    
    /// @notice Percentage allocated to project (0-100)
    uint256 public projectAllocationPercent;
    
    /// @notice Initial liquidity tokens allocated (for tracking)
    uint256 public initialLiquidityTokens;
    
    /// @notice Authorized addresses (orderbook, vault, etc.)
    mapping(address => bool) public authorized;
    
    /// @notice Total token supply
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1B tokens
    
    // ============ Events ============
    
    event AssetMetadataUpdated(string assetType, string description, uint256 totalValue, string url);
    event ProjectWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event AuthorizedUpdated(address indexed account, bool authorized);
    event LiquidityTokensTransferred(address indexed to, uint256 amount);
    
    // ============ Errors ============
    
    error InvalidAssetType();
    error InvalidProjectWallet();
    error InvalidAllocationPercent();
    error InsufficientLiquidityTokens();
    error NotAuthorized();
    error InvalidTotalValue();
    
    // ============ Modifiers ============
    
    modifier onlyAuthorized() {
        if (!authorized[msg.sender] && msg.sender != owner()) revert NotAuthorized();
        _;
    }

    // ============ Constructor ============
    
    constructor(
        string memory name_,
        string memory symbol_,
        AssetMetadata memory metadata_,
        address projectWallet_,
        uint256 projectAllocationPercent_,
        address initialOwner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) Ownable(initialOwner_) {
        // Validate inputs
        if (bytes(metadata_.assetType).length == 0) revert InvalidAssetType();
        if (projectWallet_ == address(0)) revert InvalidProjectWallet();
        if (projectAllocationPercent_ > 100) revert InvalidAllocationPercent();
        if (metadata_.totalValue == 0) revert InvalidTotalValue();
        
        // Set metadata
        assetData = metadata_;
        assetData.createdAt = block.timestamp;
        
        // Set project configuration
        projectWallet = projectWallet_;
        projectAllocationPercent = projectAllocationPercent_;
        
        // Calculate allocations
        uint256 projectTokens = (TOTAL_SUPPLY * projectAllocationPercent_) / 100;
        initialLiquidityTokens = TOTAL_SUPPLY - projectTokens;
        
        // Mint tokens
        if (projectTokens > 0) {
            _mint(projectWallet_, projectTokens);
        }
        
        // Mint liquidity tokens to this contract (will be transferred to DEX)
        if (initialLiquidityTokens > 0) {
            _mint(address(this), initialLiquidityTokens);
        }
    }

    // ============ Core Functions ============
    
    /**
     * @notice Update asset metadata (owner only)
     * @param newMetadata New asset metadata
     */
    function updateAssetMetadata(AssetMetadata memory newMetadata) external onlyOwner {
        if (bytes(newMetadata.assetType).length == 0) revert InvalidAssetType();
        if (newMetadata.totalValue == 0) revert InvalidTotalValue();
        
        assetData.assetType = newMetadata.assetType;
        assetData.description = newMetadata.description;
        assetData.totalValue = newMetadata.totalValue;
        assetData.url = newMetadata.url;
        // Keep original createdAt timestamp
        
        emit AssetMetadataUpdated(
            newMetadata.assetType,
            newMetadata.description,
            newMetadata.totalValue,
            newMetadata.url
        );
    }
    
    /**
     * @notice Update project wallet (owner only)
     * @param newProjectWallet New project wallet address
     */
    function updateProjectWallet(address newProjectWallet) external onlyOwner {
        if (newProjectWallet == address(0)) revert InvalidProjectWallet();
        
        address oldWallet = projectWallet;
        projectWallet = newProjectWallet;
        
        emit ProjectWalletUpdated(oldWallet, newProjectWallet);
    }
    
    /**
     * @notice Set authorized address (owner only)
     * @param account Address to authorize/deauthorize
     * @param auth Authorization status
     */
    function setAuthorized(address account, bool auth) external onlyOwner {
        authorized[account] = auth;
        emit AuthorizedUpdated(account, auth);
    }
    
    /**
     * @notice Transfer liquidity tokens to DEX (authorized only)
     * @param to Address to transfer tokens to (typically orderbook)
     * @param amount Amount of tokens to transfer
     */
    function transferLiquidityTokens(address to, uint256 amount) external onlyAuthorized {
        if (amount > balanceOf(address(this))) revert InsufficientLiquidityTokens();
        
        _transfer(address(this), to, amount);
        
        emit LiquidityTokensTransferred(to, amount);
    }

    // ============ View Functions ============
    
    /**
     * @notice Get available liquidity tokens remaining in this contract
     * @return Amount of liquidity tokens still in contract
     */
    function getAvailableLiquidityTokens() external view returns (uint256) {
        return balanceOf(address(this));
    }
    
    /**
     * @notice Get initial liquidity allocation amount
     * @return Initial amount allocated for liquidity
     */
    function getInitialLiquidityAllocation() external view returns (uint256) {
        return initialLiquidityTokens;
    }
    
    /**
     * @notice Get asset price per token in USD (8 decimals)
     * @return Price per token
     */
    function getPricePerToken() external view returns (uint256) {
        if (totalSupply() == 0) return 0;
        return assetData.totalValue * 1e18 / totalSupply();
    }
    
    /**
     * @notice Get total market cap in USD (8 decimals)
     * @return Market cap
     */
    function getMarketCap() external view returns (uint256) {
        return assetData.totalValue;
    }
    
    /**
     * @notice Get project allocation details
     * @return projectTokens Amount of tokens allocated to project
     * @return liquidityTokensTotal Amount of tokens allocated to liquidity
     * @return percentToProject Percentage allocated to project
     */
    function getAllocationDetails() external view returns (
        uint256 projectTokens,
        uint256 liquidityTokensTotal,
        uint256 percentToProject
    ) {
        projectTokens = (TOTAL_SUPPLY * projectAllocationPercent) / 100;
        liquidityTokensTotal = initialLiquidityTokens;
        percentToProject = projectAllocationPercent;
    }
    
    /**
     * @notice Check if address is authorized
     * @param account Address to check
     * @return Authorization status
     */
    function isAuthorized(address account) external view returns (bool) {
        return authorized[account] || account == owner();
    }

    // ============ Admin Functions ============
    
    /**
     * @notice Pause contract (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Unpause contract (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @notice Emergency withdraw any ERC20 tokens sent to contract
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Withdraw ETH
            payable(owner()).transfer(amount);
        } else if (token != address(this)) {
            // Withdraw ERC20 tokens (but not RWA tokens)
            IERC20(token).transfer(owner(), amount);
        }
    }

    // ============ Overrides ============
    
    /**
     * @notice Override transfer to add pause functionality
     */
    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @notice Override transferFrom to add pause functionality
     */
    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    // ============ Receive Function ============
    
    // Removed receive() function to avoid payable fallback conversion issues
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RWAPriceOracle
 * @notice Manual price oracle for RWA tokens
 */
contract RWAPriceOracle is Ownable, ReentrancyGuard {

    // ---------------------------------------------------------------------
    // ░░ Structs & Storage ░░
    // ---------------------------------------------------------------------

    struct RWAAssetPrice {
        uint256 price;           // Price in USD (18 decimals)
        uint256 lastUpdate;
        uint256 confidence;      // Confidence score (0-100)
        bool verified;
        string priceSource;      // Source of price data
    }

    struct AssetConfig {
        string assetType;        // Asset type identifier
        uint256 updateInterval;  // Min time between updates
        bool isActive;          // Asset is actively tracked
    }

    /// @notice RWA asset prices
    mapping(address => RWAAssetPrice) public assetPrices;

    /// @notice Asset configurations
    mapping(address => AssetConfig) public assetConfigs;

    /// @notice Authorized price updaters
    mapping(address => bool) public priceUpdaters;

    /// @notice List of tracked RWA tokens
    address[] public trackedTokens;
    mapping(address => bool) public isTracked;

    /// @notice Default update interval
    uint256 public defaultUpdateInterval = 3600; // 1 hour

    // ---------------------------------------------------------------------
    // ░░ Events ░░
    // ---------------------------------------------------------------------

    event AssetPriceUpdated(address indexed rwaToken, uint256 price, uint256 confidence, string source);
    event PriceUpdaterSet(address indexed updater, bool authorized);
    event AssetAdded(address indexed rwaToken, string assetType);
    event AssetConfigUpdated(address indexed rwaToken, AssetConfig config);
    event AssetRemoved(address indexed rwaToken);

    // ---------------------------------------------------------------------
    // ░░ Modifiers ░░
    // ---------------------------------------------------------------------

    modifier onlyPriceUpdater() {
        require(priceUpdaters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier onlyTrackedAsset(address rwaToken) {
        require(isTracked[rwaToken], "Asset not tracked");
        _;
    }

    // ---------------------------------------------------------------------
    // ░░ Constructor ░░
    // ---------------------------------------------------------------------

    constructor(address initialOwner) Ownable(initialOwner) {
        priceUpdaters[initialOwner] = true;
    }

    // ---------------------------------------------------------------------
    // ░░ Asset Management ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Add RWA token for price tracking
     * @param rwaToken RWA token address
     * @param assetType Asset type identifier
     */
    function addAsset(address rwaToken, string memory assetType) external onlyOwner {
        require(rwaToken != address(0), "Invalid token address");
        require(!isTracked[rwaToken], "Asset already tracked");
        
        assetConfigs[rwaToken] = AssetConfig({
            assetType: assetType,
            updateInterval: defaultUpdateInterval,
            isActive: true
        });
        
        trackedTokens.push(rwaToken);
        isTracked[rwaToken] = true;
        
        emit AssetAdded(rwaToken, assetType);
    }

    /**
     * @notice Remove RWA token from tracking
     * @param rwaToken RWA token address
     */
    function removeAsset(address rwaToken) external onlyOwner onlyTrackedAsset(rwaToken) {
        assetConfigs[rwaToken].isActive = false;
        isTracked[rwaToken] = false;
        
        // Remove from tracked tokens array
        for (uint256 i = 0; i < trackedTokens.length; i++) {
            if (trackedTokens[i] == rwaToken) {
                trackedTokens[i] = trackedTokens[trackedTokens.length - 1];
                trackedTokens.pop();
                break;
            }
        }
        
        emit AssetRemoved(rwaToken);
    }

    /**
     * @notice Update asset configuration
     * @param rwaToken RWA token address
     * @param config New configuration
     */
    function updateAssetConfig(
        address rwaToken,
        AssetConfig memory config
    ) external onlyOwner onlyTrackedAsset(rwaToken) {
        assetConfigs[rwaToken] = config;
        emit AssetConfigUpdated(rwaToken, config);
    }

    // ---------------------------------------------------------------------
    // ░░ Price Management ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Update RWA asset price manually
     * @param rwaToken RWA token address
     * @param price Price in USD (18 decimals)
     * @param confidence Confidence score (0-100)
     * @param source Source of price data
     */
    function updateAssetPrice(
        address rwaToken,
        uint256 price,
        uint256 confidence,
        string memory source
    ) external onlyPriceUpdater nonReentrant {
        require(price > 0, "Price must be positive");
        require(confidence <= 100, "Invalid confidence score");
        require(isTracked[rwaToken], "Asset not tracked");
        
        // Check if enough time has passed since last update
        AssetConfig memory config = assetConfigs[rwaToken];
        RWAAssetPrice memory currentPrice = assetPrices[rwaToken];
        
        if (currentPrice.lastUpdate > 0) {
            require(
                block.timestamp >= currentPrice.lastUpdate + config.updateInterval,
                "Update too frequent"
            );
        }
        
        assetPrices[rwaToken] = RWAAssetPrice({
            price: price,
            lastUpdate: block.timestamp,
            confidence: confidence,
            verified: true,
            priceSource: source
        });
        
        emit AssetPriceUpdated(rwaToken, price, confidence, source);
    }

    /**
     * @notice Batch update multiple asset prices
     * @param rwaTokens Array of RWA token addresses
     * @param prices Array of prices
     * @param confidences Array of confidence scores
     * @param source Source of price data
     */
    function batchUpdatePrices(
        address[] memory rwaTokens,
        uint256[] memory prices,
        uint256[] memory confidences,
        string memory source
    ) external onlyPriceUpdater nonReentrant {
        require(
            rwaTokens.length == prices.length && 
            prices.length == confidences.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < rwaTokens.length; i++) {
            if (isTracked[rwaTokens[i]] && prices[i] > 0 && confidences[i] <= 100) {
                assetPrices[rwaTokens[i]] = RWAAssetPrice({
                    price: prices[i],
                    lastUpdate: block.timestamp,
                    confidence: confidences[i],
                    verified: true,
                    priceSource: source
                });
                
                emit AssetPriceUpdated(rwaTokens[i], prices[i], confidences[i], source);
            }
        }
    }

    // ---------------------------------------------------------------------
    // ░░ View Functions ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Get latest price for RWA asset
     * @param rwaToken RWA token address
     * @return price Price in USD (18 decimals)
     * @return lastUpdate Last update timestamp
     * @return confidence Confidence score
     * @return source Price source
     */
    function getAssetPrice(address rwaToken) external view returns (
        uint256 price,
        uint256 lastUpdate,
        uint256 confidence,
        string memory source
    ) {
        RWAAssetPrice memory assetPrice = assetPrices[rwaToken];
        return (assetPrice.price, assetPrice.lastUpdate, assetPrice.confidence, assetPrice.priceSource);
    }

    /**
     * @notice Check if price data is fresh
     * @param rwaToken RWA token address
     * @param maxAge Maximum age in seconds
     * @return fresh True if data is fresh
     */
    function isPriceFresh(address rwaToken, uint256 maxAge) external view returns (bool fresh) {
        RWAAssetPrice memory assetPrice = assetPrices[rwaToken];
        return (block.timestamp - assetPrice.lastUpdate) <= maxAge;
    }

    /**
     * @notice Get all tracked tokens
     * @return Array of tracked token addresses
     */
    function getTrackedTokens() external view returns (address[] memory) {
        return trackedTokens;
    }

    /**
     * @notice Get asset configuration
     * @param rwaToken RWA token address
     * @return config Asset configuration
     */
    function getAssetConfig(address rwaToken) external view returns (AssetConfig memory config) {
        return assetConfigs[rwaToken];
    }

    /**
     * @notice Get prices for multiple assets
     * @param rwaTokens Array of RWA token addresses
     * @return prices Array of price data
     */
    function getBatchPrices(address[] memory rwaTokens) external view returns (RWAAssetPrice[] memory prices) {
        prices = new RWAAssetPrice[](rwaTokens.length);
        for (uint256 i = 0; i < rwaTokens.length; i++) {
            prices[i] = assetPrices[rwaTokens[i]];
        }
        return prices;
    }

    /**
     * @notice Check if asset needs price update
     * @param rwaToken RWA token address
     * @return needsUpdate True if update is needed
     */
    function needsPriceUpdate(address rwaToken) external view returns (bool needsUpdate) {
        if (!isTracked[rwaToken]) return false;
        
        AssetConfig memory config = assetConfigs[rwaToken];
        RWAAssetPrice memory currentPrice = assetPrices[rwaToken];
        
        if (currentPrice.lastUpdate == 0) return true;
        
        return (block.timestamp >= currentPrice.lastUpdate + config.updateInterval);
    }

    // ---------------------------------------------------------------------
    // ░░ Admin Functions ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Set price updater authorization
     * @param updater Address to authorize/deauthorize
     * @param authorized Authorization status
     */
    function setPriceUpdater(address updater, bool authorized) external onlyOwner {
        require(updater != address(0), "Invalid updater address");
        priceUpdaters[updater] = authorized;
        emit PriceUpdaterSet(updater, authorized);
    }

    /**
     * @notice Set default update interval
     * @param interval New default interval in seconds
     */
    function setDefaultUpdateInterval(uint256 interval) external onlyOwner {
        require(interval >= 60, "Interval too short"); // Min 1 minute
        defaultUpdateInterval = interval;
    }

    /**
     * @notice Emergency price update (bypasses time restrictions)
     * @param rwaToken RWA token address
     * @param price Emergency price
     * @param source Source description
     */
    function emergencyPriceUpdate(
        address rwaToken,
        uint256 price,
        string memory source
    ) external onlyOwner {
        require(price > 0, "Price must be positive");
        require(isTracked[rwaToken], "Asset not tracked");
        
        assetPrices[rwaToken] = RWAAssetPrice({
            price: price,
            lastUpdate: block.timestamp,
            confidence: 50, // Lower confidence for emergency updates
            verified: true,
            priceSource: string.concat("EMERGENCY: ", source)
        });
        
        emit AssetPriceUpdated(rwaToken, price, 50, string.concat("EMERGENCY: ", source));
    }
}
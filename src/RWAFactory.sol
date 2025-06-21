// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RWAToken.sol";
import "./RWAOrderbook.sol";
import "./RWAVault.sol";

/**
 * @title RWAFactory
 * @notice Factory contract for deploying RWA tokens, orderbooks, and vaults
 */
contract RWAFactory is Ownable, ReentrancyGuard {

    // ---------------------------------------------------------------------
    // ░░ Structs & Storage ░░
    // ---------------------------------------------------------------------

    struct RWAProject {
        address rwaToken;
        address orderbook;
        address vault;
        address creator;
        uint256 createdAt;
        bool isActive;
    }

    /// @notice All RWA projects
    mapping(uint256 => RWAProject) public projects;

    /// @notice Project counter
    uint256 public projectCounter;

    /// @notice Creator to project IDs
    mapping(address => uint256[]) public creatorProjects;

    /// @notice RWA token to project ID
    mapping(address => uint256) public tokenToProject;

    /// @notice Default fee recipient
    address public defaultFeeRecipient;

    /// @notice Default treasury
    address public defaultTreasury;

    /// @notice Platform fee in basis points
    uint256 public platformFee = 100; // 1%

    // ---------------------------------------------------------------------
    // ░░ Events ░░
    // ---------------------------------------------------------------------

    event RWAProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        address rwaToken,
        address orderbook,
        address vault,
        string name,
        string symbol
    );

    event ProjectStatusChanged(uint256 indexed projectId, bool isActive);

    // ---------------------------------------------------------------------
    // ░░ Constructor ░░
    // ---------------------------------------------------------------------

    constructor(
        address _defaultFeeRecipient,
        address _defaultTreasury,
        address initialOwner
    ) Ownable(initialOwner) {
        defaultFeeRecipient = _defaultFeeRecipient;
        defaultTreasury = _defaultTreasury;
    }

    // ---------------------------------------------------------------------
    // ░░ Main Functions ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Create a new RWA project with token, orderbook, and vault
     * @param name Token name
     * @param symbol Token symbol
     * @param metadata Asset metadata
     * @param projectWallet Project treasury wallet
     * @param projectAllocationPercent Percentage allocated to project (0-100)
     * @param initialPrice Initial price for orderbook in wei per token
     */
    function createRWAProject(
        string memory name,
        string memory symbol,
        RWAToken.AssetMetadata memory metadata,
        address projectWallet,
        uint256 projectAllocationPercent,
        uint256 initialPrice
    ) external nonReentrant returns (uint256 projectId) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");
        require(projectWallet != address(0), "Invalid project wallet");
        require(initialPrice > 0, "Initial price required");

        projectId = ++projectCounter;

        // Deploy RWA Token with factory as temporary owner for setup
        RWAToken rwaToken = new RWAToken(
            name,
            symbol,
            metadata,
            projectWallet,
            projectAllocationPercent,
            address(this) // Factory as initial owner for setup
        );

        // Deploy Orderbook with factory as owner initially
        RWAOrderbook orderbook = new RWAOrderbook(
            address(rwaToken),
            defaultFeeRecipient,
            address(this) // Factory as initial owner
        );

        // Deploy Vault with factory as owner initially
        RWAVault vault = new RWAVault(
            address(rwaToken),
            msg.sender, // Creator as initial reward distributor
            address(this) // Factory as initial owner
        );

        // Setup project
        projects[projectId] = RWAProject({
            rwaToken: address(rwaToken),
            orderbook: address(orderbook),
            vault: address(vault),
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true
        });

        creatorProjects[msg.sender].push(projectId);
        tokenToProject[address(rwaToken)] = projectId;

        // Setup liquidity and authorization while factory is still owner
        rwaToken.setAuthorized(address(orderbook), true);
        uint256 liquidityTokens = rwaToken.getAvailableLiquidityTokens();
        if (liquidityTokens > 0) {
            rwaToken.transferLiquidityTokens(address(orderbook), liquidityTokens);
            orderbook.addInitialLiquidity(initialPrice);
        }

        // Transfer ownership to creator
        rwaToken.transferOwnership(msg.sender);
        orderbook.transferOwnership(msg.sender);
        vault.transferOwnership(msg.sender);

        emit RWAProjectCreated(
            projectId,
            msg.sender,
            address(rwaToken),
            address(orderbook),
            address(vault),
            name,
            symbol
        );
    }

    // ---------------------------------------------------------------------
    // ░░ View Functions ░░
    // ---------------------------------------------------------------------

    function getProject(uint256 projectId) external view returns (RWAProject memory) {
        return projects[projectId];
    }

    function getCreatorProjects(address creator) external view returns (uint256[] memory) {
        return creatorProjects[creator];
    }

    function getProjectByToken(address token) external view returns (RWAProject memory) {
        uint256 projectId = tokenToProject[token];
        return projects[projectId];
    }

    function getAllActiveProjects() external view returns (RWAProject[] memory) {
        uint256 activeCount = 0;
        
        // Count active projects
        for (uint256 i = 1; i <= projectCounter; i++) {
            if (projects[i].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active projects
        RWAProject[] memory activeProjects = new RWAProject[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= projectCounter; i++) {
            if (projects[i].isActive) {
                activeProjects[index] = projects[i];
                index++;
            }
        }
        
        return activeProjects;
    }

    // ---------------------------------------------------------------------
    // ░░ Admin Functions ░░
    // ---------------------------------------------------------------------

    function setProjectStatus(uint256 projectId, bool isActive) external onlyOwner {
        require(projects[projectId].creator != address(0), "Project does not exist");
        projects[projectId].isActive = isActive;
        emit ProjectStatusChanged(projectId, isActive);
    }

    function setDefaultFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        defaultFeeRecipient = _feeRecipient;
    }

    function setDefaultTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        defaultTreasury = _treasury;
    }

    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        require(_platformFee <= 1000, "Fee too high"); // Max 10%
        platformFee = _platformFee;
    }
}
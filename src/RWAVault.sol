// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./RWAToken.sol";

/**
 * @title RWAVault
 * @notice Vault for staking RWA tokens and earning yield rewards
 * @dev Users stake RWA tokens to earn rewards from real-world asset income
 */
contract RWAVault is ReentrancyGuard, Ownable, Pausable {

    // ---------------------------------------------------------------------
    // ░░ Structs & Storage ░░
    // ---------------------------------------------------------------------

    struct UserInfo {
        uint256 shares;           // Share tokens owned by user
        uint256 rewardDebt;       // Amount of rewards already accounted for
        uint256 depositTime;     // When user deposited (for lock period)
    }

    /// @notice RWA token contract
    RWAToken public immutable rwaToken;

    /// @notice Total share tokens issued
    uint256 public totalShares;

    /// @notice Total RWA tokens staked in vault
    uint256 public totalStaked;

    /// @notice Total rewards available for distribution
    uint256 public totalRewards;

    /// @notice Accumulated rewards per share (scaled by PRECISION_FACTOR)
    uint256 public accRewardPerShare;

    /// @notice Precision factor for calculations
    uint256 private constant PRECISION_FACTOR = 1e12;

    /// @notice User information
    mapping(address => UserInfo) public userInfo;

    /// @notice Reward distributor address (project owner)
    address public rewardDistributor;

    /// @notice Minimum lock period in seconds
    uint256 public minLockPeriod = 24 * 60 * 60; // 24 hours

    // ---------------------------------------------------------------------
    // ░░ Events ░░
    // ---------------------------------------------------------------------

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 shares, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsAdded(address indexed from, uint256 amount);
    event RewardDistributorSet(address indexed distributor);  

    // ---------------------------------------------------------------------
    // ░░ Modifiers ░░
    // ---------------------------------------------------------------------

    modifier onlyRewardDistributor() {
        require(msg.sender == rewardDistributor || msg.sender == owner(), "Not reward distributor");
        _;
    }

    // ---------------------------------------------------------------------
    // ░░ Constructor ░░
    // ---------------------------------------------------------------------

    constructor(
        address _rwaToken,
        address _rewardDistributor, 
        address initialOwner
    ) Ownable(initialOwner) {
        require(_rwaToken != address(0), "Invalid RWA token");
        require(_rewardDistributor != address(0), "Invalid reward distributor"); 
        
        rwaToken = RWAToken(payable(_rwaToken));
        rewardDistributor = _rewardDistributor; 
    }

    // ---------------------------------------------------------------------
    // ░░ Main Functions ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Deposit RWA tokens and receive share tokens
     * @param amount Amount of RWA tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be positive");
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Transfer RWA tokens from user
        rwaToken.transferFrom(msg.sender, address(this), amount);
        
        // Calculate shares to mint
        uint256 shares;
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalStaked;
        }
        
        // Claim pending rewards first
        if (user.shares > 0) {
            uint256 pending = pendingRewards(msg.sender);
            if (pending > 0) {
                _safeRewardTransfer(msg.sender, pending);
                emit RewardsClaimed(msg.sender, pending);
            }
        }
        
        // Update user info
        user.shares += shares;
        user.depositTime = block.timestamp;
        user.rewardDebt = (user.shares * accRewardPerShare) / PRECISION_FACTOR;
        
        // Update totals
        totalShares += shares;
        totalStaked += amount;
        
        emit Deposit(msg.sender, amount, shares);
    }

    /**
     * @notice Withdraw RWA tokens by burning share tokens
     * @param shares Amount of share tokens to burn
     */
    function withdraw(uint256 shares) external nonReentrant {
        require(shares > 0, "Shares must be positive");
        
        UserInfo storage user = userInfo[msg.sender];
        require(user.shares >= shares, "Insufficient shares");
        require(block.timestamp >= user.depositTime + minLockPeriod, "Still locked");
        
        // Calculate RWA tokens to return
        uint256 amount = (shares * totalStaked) / totalShares;
        
        // Claim pending rewards
        uint256 pending = pendingRewards(msg.sender);
        if (pending > 0) {
            _safeRewardTransfer(msg.sender, pending);
            emit RewardsClaimed(msg.sender, pending);
        }
        
        // Update user info
        user.shares -= shares;
        user.rewardDebt = (user.shares * accRewardPerShare) / PRECISION_FACTOR;
        
        // Update totals
        totalShares -= shares;
        totalStaked -= amount;
        
        // Transfer RWA tokens back to user
        rwaToken.transfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, shares, amount);
    }

    /**
     * @notice Claim pending rewards without withdrawing
     */
    function claimRewards() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = pendingRewards(msg.sender);
        
        require(pending > 0, "No pending rewards");
        
        user.rewardDebt = (user.shares * accRewardPerShare) / PRECISION_FACTOR;
        _safeRewardTransfer(msg.sender, pending);
        
        emit RewardsClaimed(msg.sender, pending);
    }
 

    /**
     * @notice Add rewards to the vault (caller pays)
     * @param amount Amount of RWA tokens to add as rewards
     */
    function addRewards(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(totalShares > 0, "No stakers to reward");
        
        // Transfer reward tokens from caller
        rwaToken.transferFrom(msg.sender, address(this), amount);
        
        // Update rewards per share
        accRewardPerShare += (amount * PRECISION_FACTOR) / totalShares;
        totalRewards += amount;

        emit RewardsAdded(msg.sender, amount);
    }

    /**
     * @notice Simplified reward addition - project can directly send tokens to vault
     * @param amount Amount of rewards to distribute to stakers
     */
    function distributeRewardsFromBalance(uint256 amount) external onlyRewardDistributor {
        require(amount > 0, "Amount must be positive");
        require(totalShares > 0, "No stakers to reward");
        
        uint256 vaultBalance = rwaToken.balanceOf(address(this));
        uint256 availableForRewards = vaultBalance - totalStaked;
        require(availableForRewards >= amount, "Insufficient reward balance");
         
        // Update rewards per share
        accRewardPerShare += (amount * PRECISION_FACTOR) / totalShares;
        totalRewards += amount;
        
        emit RewardsAdded(address(this), amount);
    }

    // ---------------------------------------------------------------------
    // ░░ View Functions ░░
    // ---------------------------------------------------------------------

    /**
     * @notice Get pending rewards for a user
     * @param user User address
     * @return Pending reward amount
     */
    function pendingRewards(address user) public view returns (uint256) {
        UserInfo memory userInfo_ = userInfo[user];
        return (userInfo_.shares * accRewardPerShare) / PRECISION_FACTOR - userInfo_.rewardDebt;
    }

    /**
     * @notice Get user's staked RWA token amount
     * @param user User address
     * @return RWA token amount
     */
    function getUserTokenAmount(address user) external view returns (uint256) {
        UserInfo memory userInfo_ = userInfo[user];
        if (totalShares == 0) return 0;
        return (userInfo_.shares * totalStaked) / totalShares;
    }

    /**
     * @notice Get share price (RWA tokens per share)
     * @return Share price
     */
    function getSharePrice() external view returns (uint256) {
        if (totalShares == 0) return 1e18;
        return (totalStaked * 1e18) / totalShares;
    }

    /**
     * @notice Get vault APY based on recent rewards (estimated)
     * @return APY in basis points
     */
    function getAPY() external view returns (uint256) {
        if (totalStaked == 0 || totalRewards == 0) return 0;
        
        // Simple APY calculation - this would need more sophisticated calculation in production
        // based on time periods and reward frequency
        return (totalRewards * 10000) / totalStaked; // Return in basis points
    }

    /**
     * @notice Check if user can withdraw (lock period expired)
     * @param user User address
     * @return True if user can withdraw
     */
    function canWithdraw(address user) external view returns (bool) {
        return block.timestamp >= userInfo[user].depositTime + minLockPeriod;
    }

    /**
     * @notice Get available reward balance (tokens in vault not staked)
     * @return Available reward balance
     */
    function getAvailableRewardBalance() external view returns (uint256) {
        uint256 vaultBalance = rwaToken.balanceOf(address(this));
        return vaultBalance > totalStaked ? vaultBalance - totalStaked : 0;
    }

    // ---------------------------------------------------------------------
    // ░░ Admin Functions ░░
    // ---------------------------------------------------------------------

    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        require(_rewardDistributor != address(0), "Invalid distributor");
        rewardDistributor = _rewardDistributor;
        emit RewardDistributorSet(_rewardDistributor);
    }

    function setMinLockPeriod(uint256 _minLockPeriod) external onlyOwner {
        minLockPeriod = _minLockPeriod;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ---------------------------------------------------------------------
    // ░░ Internal Functions ░░
    // ---------------------------------------------------------------------

    function _safeRewardTransfer(address to, uint256 amount) internal {
        uint256 balance = rwaToken.balanceOf(address(this));
        uint256 availableRewards = balance - totalStaked;
        
        if (amount > availableRewards) {
            rwaToken.transfer(to, availableRewards);
        } else {
            rwaToken.transfer(to, amount);
        }
    }

    // ---------------------------------------------------------------------
    // ░░ Emergency Functions ░░
    // ---------------------------------------------------------------------

    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = (user.shares * totalStaked) / totalShares;
        
        totalShares -= user.shares;
        totalStaked -= amount;
        
        user.shares = 0;
        user.rewardDebt = 0;
        
        rwaToken.transfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, user.shares, amount);
    }

    function emergencyRewardWithdraw(uint256 amount) external onlyOwner {
        rwaToken.transfer(owner(), amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./RWAToken.sol";

/**
 * @title RWAVault
 * @notice Yield and reward distribution vault for RWA token holders
 */
contract RWAVault is ReentrancyGuard, Ownable, Pausable {
    
    RWAToken public immutable rwaToken;
    
    struct UserStake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 stakedAt;
    }
    
    struct RewardDistribution {
        uint256 totalAmount;
        uint256 timestamp;
        string description;
    }
    
    mapping(address => UserStake) public stakes;
    RewardDistribution[] public distributions;
    
    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public totalRewardsDistributed;
    uint256 public minStakeAmount = 100 * 1e18;
    uint256 public stakingFee = 25; // 0.25%
    
    address public rewardDistributor;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount, string description);
    
    error InsufficientStakeAmount();
    error NoStakeFound();
    error InsufficientStaked();
    error NotDistributor();
    error NoRewards();
    
    modifier onlyDistributor() {
        if (msg.sender != rewardDistributor && msg.sender != owner()) revert NotDistributor();
        _;
    }
    
    constructor(
        address _rwaToken,
        address _owner
    ) Ownable(_owner) {
        rwaToken = RWAToken(_rwaToken);
        rewardDistributor = _owner;
    }
    
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount < minStakeAmount) revert InsufficientStakeAmount();
        
        UserStake storage userStake = stakes[msg.sender];
        
        // Claim pending rewards first
        if (userStake.amount > 0) {
            _claimRewards(msg.sender);
        }
        
        // Calculate fee
        uint256 fee = (amount * stakingFee) / 10000;
        uint256 stakeAmount = amount - fee;
        
        // Transfer tokens
        rwaToken.transferFrom(msg.sender, address(this), amount);
        
        // Update stake
        userStake.amount += stakeAmount;
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / 1e12;
        userStake.stakedAt = block.timestamp;
        
        totalStaked += stakeAmount;
        
        // Send fee to owner
        if (fee > 0) {
            rwaToken.transfer(owner(), fee);
        }
        
        emit Staked(msg.sender, stakeAmount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        UserStake storage userStake = stakes[msg.sender];
        
        if (userStake.amount == 0) revert NoStakeFound();
        if (amount > userStake.amount) revert InsufficientStaked();
        
        // Claim rewards first
        uint256 rewards = _claimRewards(msg.sender);
        
        // Update stake
        userStake.amount -= amount;
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / 1e12;
        
        totalStaked -= amount;
        
        // Transfer tokens back
        rwaToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount, rewards);
    }
    
    function claimRewards() external nonReentrant {
        uint256 rewards = _claimRewards(msg.sender);
        if (rewards == 0) revert NoRewards();
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    function _claimRewards(address user) internal returns (uint256 rewards) {
        UserStake storage userStake = stakes[user];
        
        if (userStake.amount == 0) return 0;
        
        uint256 pending = (userStake.amount * accRewardPerShare) / 1e12 - userStake.rewardDebt;
        
        if (pending > 0) {
            // Transfer ETH rewards
            payable(user).transfer(pending);
            rewards = pending;
        }
        
        userStake.rewardDebt = (userStake.amount * accRewardPerShare) / 1e12;
    }
    
    function distributeRewards(string memory description) external payable onlyDistributor {
        require(msg.value > 0, "No rewards to distribute");
        require(totalStaked > 0, "No stakers");
        
        accRewardPerShare += (msg.value * 1e12) / totalStaked;
        totalRewardsDistributed += msg.value;
        
        distributions.push(RewardDistribution({
            totalAmount: msg.value,
            timestamp: block.timestamp,
            description: description
        }));
        
        emit RewardsDistributed(msg.value, description);
    }
    
    function getPendingRewards(address user) external view returns (uint256) {
        UserStake storage userStake = stakes[user];
        
        if (userStake.amount == 0) return 0;
        
        return (userStake.amount * accRewardPerShare) / 1e12 - userStake.rewardDebt;
    }
    
    function getUserStakeInfo(address user) external view returns (
        uint256 stakedAmount,
        uint256 pendingRewards,
        uint256 stakedAt
    ) {
        UserStake storage userStake = stakes[user];
        
        stakedAmount = userStake.amount;
        pendingRewards = (userStake.amount * accRewardPerShare) / 1e12 - userStake.rewardDebt;
        stakedAt = userStake.stakedAt;
    }
    
    function getDistributionHistory() external view returns (RewardDistribution[] memory) {
        return distributions;
    }
    
    function getVaultStats() external view returns (
        uint256 totalStakedTokens,
        uint256 totalRewards,
        uint256 distributionCount,
        uint256 stakingFeePercent
    ) {
        totalStakedTokens = totalStaked;
        totalRewards = totalRewardsDistributed;
        distributionCount = distributions.length;
        stakingFeePercent = stakingFee;
    }
    
    function updateMinStakeAmount(uint256 newMin) external onlyOwner {
        minStakeAmount = newMin;
    }
    
    function updateStakingFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        stakingFee = newFee;
    }
    
    function updateRewardDistributor(address newDistributor) external onlyOwner {
        require(newDistributor != address(0), "Invalid distributor");
        rewardDistributor = newDistributor;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }
    
    receive() external payable {
        // Allow direct ETH deposits for rewards
    }
}
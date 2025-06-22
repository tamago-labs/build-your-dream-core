// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRWAVault {
    
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
    
    // Staking functions
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external;
    
    // Distribution functions
    function distributeRewards(string memory description) external payable;
    
    // View functions
    function getPendingRewards(address user) external view returns (uint256);
    function getUserStakeInfo(address user) external view returns (uint256, uint256, uint256);
    function getDistributionHistory() external view returns (RewardDistribution[] memory);
    function getVaultStats() external view returns (uint256, uint256, uint256, uint256);
    
    // Configuration
    function updateMinStakeAmount(uint256 newMin) external;
    function updateStakingFee(uint256 newFee) external;
    function updateRewardDistributor(address newDistributor) external;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount, string description);
}
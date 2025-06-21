// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRWAVault
 * @notice Interface for RWA vault contracts
 */
interface IRWAVault {
    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
        uint256 depositTime;
    }

    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function claimRewards() external; 
    function addRewards(uint256 amount) external;
    function distributeRewardsFromBalance(uint256 amount) external;
    function pendingRewards(address user) external view returns (uint256);
    function getUserTokenAmount(address user) external view returns (uint256);
    function getSharePrice() external view returns (uint256);
    function getAPY() external view returns (uint256);
    function canWithdraw(address user) external view returns (bool);
    function getAvailableRewardBalance() external view returns (uint256);
}
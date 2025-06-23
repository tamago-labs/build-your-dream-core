// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../RWAVault.sol";

/**
 * @title RWAVaultFactory
 * @notice Specialized factory for creating RWA vaults
 */
contract RWAVaultFactory is Ownable {
    
    event VaultCreated(
        uint256 indexed projectId,
        address indexed creator,
        address indexed token,
        address vault
    );
    
    constructor(address _owner) Ownable(_owner) {}
    
    /**
     * @notice Create a vault for a project
     * @param projectId Project identifier from coordinator
     * @param token RWA token address
     * @param projectCreator Project creator address
     * @return vaultAddress Address of created vault
     */
    function createVault(
        uint256 projectId,
        address token,
        address projectCreator
    ) external onlyOwner returns (address vaultAddress) {
        require(token != address(0), "Invalid token");
        require(projectCreator != address(0), "Invalid creator");
        
        // Deploy Vault
        RWAVault vault = new RWAVault(
            token,
            projectCreator
        );
        
        vaultAddress = address(vault);
        
        emit VaultCreated(
            projectId,
            projectCreator,
            token,
            vaultAddress
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../RWAToken.sol";

/**
 * @title RWATokenFactory
 * @notice Specialized factory for creating RWA tokens only
 */
contract RWATokenFactory is Ownable {
    
    event TokenCreated(
        uint256 indexed projectId,
        address indexed creator,
        address indexed token,
        string name,
        string symbol
    );
    
    constructor(address _owner) Ownable(_owner) {}
    
    /**
     * @notice Create a new RWA token
     * @param projectId Project identifier from coordinator
     * @param name Token name
     * @param symbol Token symbol
     * @param metadata Asset metadata
     * @param projectWallet Project treasury wallet
     * @param projectAllocationPercent Percentage allocated to project (0-100)
     * @param factoryOwner Factory address that will initially own the token
     * @return tokenAddress Address of created token
     */
    function createToken(
        uint256 projectId,
        string memory name,
        string memory symbol,
        RWAToken.AssetMetadata memory metadata,
        address projectWallet,
        uint256 projectAllocationPercent,
        address factoryOwner
    ) external onlyOwner returns (address tokenAddress) {
        require(bytes(name).length > 0, "Name required");
        require(bytes(symbol).length > 0, "Symbol required");
        require(projectWallet != address(0), "Invalid project wallet");
        require(factoryOwner != address(0), "Invalid factory owner");
        
        // Deploy RWA Token
        RWAToken token = new RWAToken(
            name,
            symbol,
            metadata,
            projectWallet,
            projectAllocationPercent,
            factoryOwner // Factory will be initial owner for setup
        );
        
        tokenAddress = address(token);
        
        emit TokenCreated(
            projectId,
            tx.origin, // Original caller (project creator)
            tokenAddress,
            name,
            symbol
        );
    }
}

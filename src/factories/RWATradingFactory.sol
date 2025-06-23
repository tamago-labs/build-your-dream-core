// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../RWAPrimarySales.sol";
import "../RWARFQ.sol";

/**
 * @title RWATradingFactory
 * @notice Specialized factory for creating trading contracts (PrimarySales and RFQ)
 */
contract RWATradingFactory is Ownable {
    
    event TradingContractsCreated(
        uint256 indexed projectId,
        address indexed creator,
        address indexed token,
        address primarySales,
        address rfq
    );
    
    constructor(address _owner) Ownable(_owner) {}
    
    /**
     * @notice Create trading contracts for a project
     * @param projectId Project identifier from coordinator
     * @param token RWA token address
     * @param treasury Treasury address for primary sales
     * @param feeRecipient Fee recipient for RFQ
     * @param salesAllocation Token allocation for primary sales
     * @param pricePerTokenETH Price per token in ETH
     * @param projectCreator Project creator address
     * @return primarySalesAddress Address of primary sales contract
     * @return rfqAddress Address of RFQ contract
     */
    function createTradingContracts(
        uint256 projectId,
        address token,
        address treasury,
        address feeRecipient,
        uint256 salesAllocation,
        uint256 pricePerTokenETH,
        address projectCreator
    ) external onlyOwner returns (address primarySalesAddress, address rfqAddress) {
        require(token != address(0), "Invalid token");
        require(treasury != address(0), "Invalid treasury");
        require(feeRecipient != address(0), "Invalid fee recipient");
        require(projectCreator != address(0), "Invalid creator");
        require(pricePerTokenETH > 0, "Price required");
        
        // Deploy Primary Sales
        RWAPrimarySales primarySales = new RWAPrimarySales(
            token,
            treasury,
            salesAllocation,
            pricePerTokenETH,
            projectCreator
        );
        
        // Deploy RFQ
        RWARFQ rfq = new RWARFQ(
            token,
            feeRecipient,
            projectCreator
        );
        
        primarySalesAddress = address(primarySales);
        rfqAddress = address(rfq);
        
        emit TradingContractsCreated(
            projectId,
            projectCreator,
            token,
            primarySalesAddress,
            rfqAddress
        );
    }
}

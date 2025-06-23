// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWADashboard.sol";

contract ViewProjects is Script {
    
    function run() external view {
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address dashboardAddress = vm.envAddress("DASHBOARD_ADDRESS");
        
        console.log("=== RWA Framework Status - Avalanche Fuji ===");
        console.log("Factory:", factoryAddress);
        console.log("Dashboard:", dashboardAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Explorer: https://testnet.snowtrace.io/");
        
        RWAFactory factory = RWAFactory(factoryAddress);
        RWADashboard dashboard = RWADashboard(dashboardAddress);
        
        // Get factory stats
        (uint256 totalProjects,   address feeRecipient, address treasury) = dashboard.getFactoryStats();
        
        console.log("\n--- Factory Statistics ---");
        console.log("Total Projects:", totalProjects); 
        console.log("Fee Recipient:", feeRecipient);
        console.log("Treasury:", treasury);
        
        if (totalProjects == 0) {
            console.log("\nNo projects created yet. Use CreateProject.s.sol to create your first project!");
            return;
        }
        
        // Show all projects
        console.log("\n--- All Projects ---");
        for (uint256 i = 1; i <= totalProjects; i++) {
            console.log("\nProject", i, ":");
            
            try dashboard.getProjectOverview(i) returns (RWADashboard.ProjectOverview memory overview) {
                console.log("  Name:", overview.name);
                console.log("  Symbol:", overview.symbol);
                console.log("  Asset Type:", overview.assetType);
                console.log("  Creator:", overview.creator);
                console.log("  Active:", overview.isActive);
                console.log("  Total Supply:", overview.totalSupply / 1e18);
                console.log("  Market Cap: $", overview.marketCap / 1e8);
                console.log("  Price per Token: $", overview.pricePerToken / 1e8 / 1e18);
                console.log("  Total Allocation:", overview.totalAllocation / 1e18);
                console.log("  Total Sold:", overview.totalSold / 1e18);
                console.log("  Sales Price:", overview.salesPriceETH, "wei");
                console.log("  Total Staked:", overview.totalStaked / 1e18);
                console.log("  Rewards Distributed:", overview.totalRewardsDistributed / 1e18, "AVAX");
                console.log("  Active Quotes:", overview.activeQuotesCount);
                
                // Get project addresses
                (address rwaToken, address primarySales, address rfq, address vault) = dashboard.getProjectAddresses(i);
                console.log("  Addresses:");
                console.log("    Token:", rwaToken);
                console.log("    Primary Sales:", primarySales);
                console.log("    RFQ:", rfq);
                console.log("    Vault:", vault);
                
            } catch {
                console.log("  ERROR: Error fetching project overview");
            }
        }
        
        console.log("\n=== User Data Example ===");
        console.log("To check user data for a project, use:");
        console.log("dashboard.getUserProjectData(projectId, userAddress)");
        
        console.log("\n=== Market Activity ===");
        console.log("To check RFQ market activity, use:");
        console.log("dashboard.getMarketActivity(projectId)");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWAPrimarySales.sol";
import "../src/RWAToken.sol";

contract ManageProject is Script {
    
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;
        
        // Handle private key with or without 0x prefix
        if (bytes(privateKeyString)[0] == '0' && bytes(privateKeyString)[1] == 'x') {
            deployerPrivateKey = vm.parseUint(privateKeyString);
        } else {
            deployerPrivateKey = vm.parseUint(string(abi.encodePacked("0x", privateKeyString)));
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        uint256 projectId = vm.envUint("PROJECT_ID");
        
        console.log("=== Managing RWA Project ===");
        console.log("Factory:", factoryAddress);
        console.log("Project ID:", projectId);
        console.log("Manager:", deployer);
        
        RWAFactory factory = RWAFactory(factoryAddress);
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        require(project.creator == deployer, "Only project creator can manage");
        require(project.isActive, "Project is not active");
        
        RWAToken token = RWAToken(project.rwaToken);
        RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
        
        console.log("Token:", address(token));
        console.log("Primary Sales:", address(sales));
        console.log("Token Owner:", token.owner());
        console.log("Sales Owner:", sales.owner());
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example management operations
        console.log("\n--- Management Operations ---");
        
        // 1. Whitelist some investors
        console.log("1. Whitelisting investors...");
        address[] memory investors = new address[](3);
        investors[0] = 0x1234567890123456789012345678901234567890; // Replace with real addresses
        investors[1] = 0x2345678901234567890123456789012345678901;
        investors[2] = 0x3456789012345678901234567890123456789012;
        
        sales.whitelistUsers(investors, true);
        console.log("SUCCESS: Whitelisted", investors.length, "investors");
        
        // 2. Update purchase limits (optional)
        console.log("2. Updating purchase limits...");
        sales.updateLimits(
            0.1 ether,  // Min purchase: 0.1 AVAX
            50 ether    // Max purchase: 50 AVAX
        );
        console.log("SUCCESS: Updated limits: 0.1 AVAX min, 50 AVAX max");
        
        // 3. Check current sales status
        console.log("\n--- Sales Status ---");
        console.log("Total Allocation:", sales.totalAllocation() / 1e18, "tokens");
        console.log("Total Sold:", sales.totalSold() / 1e18, "tokens");
        console.log("Price per Token:", sales.pricePerTokenETH(), "wei");
        console.log("Remaining:", (sales.totalAllocation() - sales.totalSold()) / 1e18, "tokens");
        
        vm.stopBroadcast();
        
        console.log("\n=== Management Complete ===");
        console.log("SUCCESS: Investors whitelisted");
        console.log("SUCCESS: Purchase limits updated");
        console.log("SUCCESS: Project ready for primary sales");
        
        console.log("\n=== Available Management Functions ===");
        console.log("sales.whitelistUsers(addresses[], true/false)");
        console.log("sales.updatePrice(newPriceWei)");
        console.log("sales.updateLimits(minWei, maxWei)");
        console.log("sales.pause() / sales.unpause()");
        console.log("token.updateAssetMetadata(newMetadata)");
        console.log("vault.distributeRewards{value: amount}(description)");
    }
}
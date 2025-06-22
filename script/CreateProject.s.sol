// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWAToken.sol";

contract CreateProject is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        console.log("=== Creating RWA Project ===");
        console.log("Factory:", factoryAddress);
        console.log("Creator:", deployer);
        console.log("Creator balance:", deployer.balance / 1e18, "ETH");
        
        RWAFactory factory = RWAFactory(factoryAddress);
        uint256 creationFee = factory.creationFee();
        
        require(deployer.balance >= creationFee, "Insufficient ETH for creation fee");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example: Luxury Real Estate Project
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Premium office building in downtown Manhattan. 50-story tower with 100% occupancy rate, premium tenants including Fortune 500 companies. Professional property management with 15-year average lease terms.",
            totalValue: 150_000_000 * 1e8, // $150M USD with 8 decimals
            url: "https://example.com/manhattan-tower",
            createdAt: 0 // Will be set by contract
        });
        
        console.log("\n--- Project Configuration ---");
        console.log("Asset Type:", metadata.assetType);
        console.log("Asset Value: $", metadata.totalValue / 1e8);
        console.log("Creation Fee:", creationFee / 1e18, "ETH");
        
        uint256 projectId = factory.createRWAProject{value: creationFee}(
            "Manhattan Tower REIT",     // Token name
            "MHTNRT",                  // Token symbol  
            metadata,                  // Asset metadata
            deployer,                  // Project wallet (receives project allocation)
            20,                        // 20% allocation to project, 80% for sales
            0.00015 ether              // 0.00015 ETH per token (~$150M / 1B tokens = $0.15 per token)
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Project Created Successfully! ===");
        console.log("✅ Project ID:", projectId);
        
        // Get project details
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        console.log("✅ RWA Token:", project.rwaToken);
        console.log("✅ Primary Sales:", project.primarySales);
        console.log("✅ RFQ Market:", project.rfq);
        console.log("✅ Staking Vault:", project.vault);
        console.log("✅ Project Creator:", project.creator);
        console.log("✅ Is Active:", project.isActive);
        
        // Token details
        RWAToken token = RWAToken(project.rwaToken);
        console.log("\n--- Token Details ---");
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply() / 1e18);
        console.log("Market Cap: $", token.getMarketCap() / 1e8);
        console.log("Price per Token: $", token.getPricePerToken() / 1e8 / 1e18);
        
        // Save project info
        string memory projectInfo = string(abi.encodePacked(
            "RWA Project Created\n",
            "===================\n",
            "Project ID: ", vm.toString(projectId), "\n",
            "Token: ", vm.toString(project.rwaToken), "\n",
            "Primary Sales: ", vm.toString(project.primarySales), "\n",
            "RFQ: ", vm.toString(project.rfq), "\n",
            "Vault: ", vm.toString(project.vault), "\n",
            "Creator: ", vm.toString(project.creator), "\n"
        ));
        
        vm.writeFile("project.txt", projectInfo);
        console.log("\n📄 Project info saved to project.txt");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Whitelist investors for primary sales");
        console.log("2. Start primary token sales");
        console.log("3. Enable secondary trading via RFQ");
        console.log("4. Distribute real-world asset yields via vault");
    }
}
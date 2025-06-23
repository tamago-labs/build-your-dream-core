// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWAToken.sol";

contract CreateProject is Script {
    
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
        
        console.log("=== Creating RWA Project on Avalanche Fuji ===");
        console.log("Factory:", factoryAddress);
        console.log("Creator:", deployer);
        console.log("Creator balance:", deployer.balance / 1e18, "AVAX");
        console.log("Chain ID:", block.chainid);
        
        require(block.chainid == 43113, "Must be on Avalanche Fuji Testnet (Chain ID: 43113)");
        
        RWAFactory factory = RWAFactory(factoryAddress); 
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example: Luxury Real Estate Project
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Premium ski resort property in Whistler, Canada. 200-unit luxury condominium complex with year-round rental income from vacation rentals and long-term leases. Professional property management with average 85% occupancy rate.",
            totalValue: 120_000_000 * 1e8, // $120M USD with 8 decimals
            url: "https://example.com/whistler-resort",
            createdAt: 0 // Will be set by contract
        });
        
        console.log("\n--- Project Configuration ---");
        console.log("Asset Type:", metadata.assetType);
        console.log("Asset Value: $", metadata.totalValue / 1e8); 
        
        uint256 projectId = factory.createRWAProject(
            "Whistler Resort Token",    // Token name
            "WHSTLR",                  // Token symbol  
            metadata,                  // Asset metadata
            deployer,                  // Project wallet (receives project allocation)
            25,                        // 25% allocation to project, 75% for sales
            0.00012 ether              // 0.00012 AVAX per token (~$120M / 1B tokens = $0.12 per token)
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Project Created Successfully! ===");
        console.log("SUCCESS: Project ID:", projectId);
        
        // Get project details
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        console.log("SUCCESS: RWA Token:", project.rwaToken);
        console.log("SUCCESS: Primary Sales:", project.primarySales);
        console.log("SUCCESS: RFQ Market:", project.rfq);
        console.log("SUCCESS: Staking Vault:", project.vault);
        console.log("SUCCESS: Project Creator:", project.creator);
        console.log("SUCCESS: Is Active:", project.isActive);
        
        // Token details
        RWAToken token = RWAToken(project.rwaToken);
        console.log("\n--- Token Details ---");
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply() / 1e18);
        console.log("Market Cap: $", token.getMarketCap() / 1e8);
        console.log("Price per Token: $", token.getPricePerToken() / 1e8 / 1e18);
        console.log("View on Snowtrace: https://testnet.snowtrace.io/address/", address(token));
        
        // Save project info
        string memory projectInfo = string(abi.encodePacked(
            "RWA Project Created - Avalanche Fuji\n",
            "====================================\n",
            "Project ID: ", vm.toString(projectId), "\n",
            "Token: ", vm.toString(project.rwaToken), "\n",
            "Primary Sales: ", vm.toString(project.primarySales), "\n",
            "RFQ: ", vm.toString(project.rfq), "\n",
            "Vault: ", vm.toString(project.vault), "\n",
            "Creator: ", vm.toString(project.creator), "\n",
            "Chain ID: ", vm.toString(block.chainid), "\n",
            "Explorer: https://testnet.snowtrace.io/\n"
        ));
        
        vm.writeFile("project.txt", projectInfo);
        console.log("\nProject info saved to project.txt");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Whitelist investors for primary sales");
        console.log("2. Start primary token sales");
        console.log("3. Enable secondary trading via RFQ");
        console.log("4. Distribute real-world asset yields via vault");
        console.log("5. Monitor project via Snowtrace explorer");
    }
}
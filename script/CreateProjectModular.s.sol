// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWACoordinator.sol";
import "../src/RWAToken.sol";

contract CreateProjectModular is Script {
    
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
        address coordinatorAddress = vm.envAddress("COORDINATOR_ADDRESS");
        
        console.log("=== Creating RWA Project with Modular Framework ===");
        console.log("Creator:", deployer);
        console.log("Coordinator:", coordinatorAddress);
        console.log("Balance:", deployer.balance / 1e18, "AVAX");
        
        RWACoordinator coordinator = RWACoordinator(coordinatorAddress);
        
        // Display factory information
        (address tokenFactory, address tradingFactory, address vaultFactory) = coordinator.getFactories();
        console.log("\n--- Factory Addresses ---");
        console.log("Token Factory:", tokenFactory);
        console.log("Trading Factory:", tradingFactory);
        console.log("Vault Factory:", vaultFactory);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Create asset metadata
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Premium commercial office building in Singapore CBD. 25-story Grade A office tower with modern facilities, LEED Gold certification, and prime Marina Bay location.",
            totalValue: 120000000 * 1e8, // $120M with 8 decimals
            url: "https://example.com/singapore-office-tower",
            createdAt: 0 // Will be set by contract
        });
        
        console.log("\n--- Creating Complete RWA Project ---");
        console.log("Asset Type:", metadata.assetType);
        console.log("Total Value: $", metadata.totalValue / 1e8);
        console.log("Project Allocation: 15%");
        console.log("Price per Token: 0.005 ETH");
        
        // Create complete project in one transaction
        uint256 projectId = coordinator.createRWAProject(
            "Singapore Office Tower Token",
            "SOTT",
            metadata,
            deployer, // Project wallet
            15, // 15% allocation to project
            0.005 ether // Price per token in ETH
        );
        
        console.log("- SUCCESS: Complete project created with ID:", projectId);
        
        // Get project details
        RWACoordinator.RWAProject memory project = coordinator.getProject(projectId);
        
        console.log("\n=== Project Details ===");
        console.log("Project ID:", projectId);
        console.log("Creator:", project.creator);
        console.log("Token:", project.rwaToken);
        console.log("Primary Sales:", project.primarySales);
        console.log("RFQ:", project.rfq);
        console.log("Vault:", project.vault);
        console.log("Active:", project.isActive);
        console.log("Created At:", project.createdAt);
        
        // Verify token details
        RWAToken token = RWAToken(project.rwaToken);
        console.log("\n=== Token Verification ===");
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Token Owner:", token.owner());
        console.log("Total Supply:", token.totalSupply() / 1e18);
        console.log("Project Wallet:", token.projectWallet());
        console.log("Project Allocation %:", token.projectAllocationPercent());
        
        // Get allocation details
        (uint256 projectTokens, uint256 liquidityTokens, uint256 percentToProject) = token.getAllocationDetails();
        console.log("Project Tokens:", projectTokens / 1e18);
        console.log("Liquidity Tokens:", liquidityTokens / 1e18);
        console.log("Percent to Project:", percentToProject);
        
        vm.stopBroadcast();
        
        console.log("\n=== Explorer Links ===");
        console.log("Token: https://testnet.snowtrace.io/address/", project.rwaToken);
        console.log("Primary Sales: https://testnet.snowtrace.io/address/", project.primarySales);
        console.log("RFQ: https://testnet.snowtrace.io/address/", project.rfq);
        console.log("Vault: https://testnet.snowtrace.io/address/", project.vault);
        
        console.log("\n=== Modular Framework Benefits Demonstrated ===");
        console.log("- All contracts deployed in single transaction");
        console.log("- No contract size limitations");
        console.log("- Clean modular architecture");
        console.log("- Each factory focused on specific functionality");
        console.log("- Coordinator orchestrates everything seamlessly");
        
        // Save project info to file
        string memory projectInfo = string(abi.encodePacked(
            "RWA Project Created - Modular Framework\n",
            "======================================\n",
            "Project ID: ", vm.toString(projectId), "\n",
            "Creator: ", vm.toString(project.creator), "\n",
            "Token: ", vm.toString(project.rwaToken), "\n",
            "Primary Sales: ", vm.toString(project.primarySales), "\n",
            "RFQ: ", vm.toString(project.rfq), "\n",
            "Vault: ", vm.toString(project.vault), "\n",
            "Created At: ", vm.toString(project.createdAt), "\n",
            "\nFactory Addresses:\n",
            "Token Factory: ", vm.toString(tokenFactory), "\n",
            "Trading Factory: ", vm.toString(tradingFactory), "\n",
            "Vault Factory: ", vm.toString(vaultFactory), "\n",
            "Coordinator: ", vm.toString(coordinatorAddress), "\n"
        ));
        
        vm.writeFile("project.txt", projectInfo);
        console.log("\nProject info saved to project.txt");
        
        console.log("\n Success! ");
        console.log("Your RWA project is now fully deployed using modular architecture!");
        console.log("All contracts created in one transaction - no size limitations!");
    }
}

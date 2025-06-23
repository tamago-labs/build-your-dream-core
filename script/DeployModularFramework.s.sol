// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/factories/RWATokenFactory.sol";
import "../src/factories/RWATradingFactory.sol";
import "../src/factories/RWAVaultFactory.sol";
import "../src/RWACoordinator.sol";
import "../src/RWADashboard.sol";

contract DeployModularFramework is Script {
    
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
        
        console.log("=== Deploying Modular RWA Framework on Avalanche Fuji ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "AVAX");
        console.log("Chain ID:", block.chainid);
        
        require(deployer.balance > 1 ether, "Insufficient AVAX balance for deployment");
        require(block.chainid == 43113, "Must deploy on Avalanche Fuji Testnet (Chain ID: 43113)");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configuration
        address feeRecipient = deployer; // Can be changed later
        address treasury = deployer; // Can be changed later
        
        console.log("Fee recipient:", feeRecipient);
        console.log("Treasury:", treasury);
        
        // Step 1: Deploy specialized factories
        console.log("\n--- Step 1: Deploying Specialized Factories ---");
        
        console.log("Deploying RWATokenFactory...");
        RWATokenFactory tokenFactory = new RWATokenFactory(deployer);
        console.log("- RWATokenFactory:", address(tokenFactory));
        
        console.log("Deploying RWATradingFactory...");
        RWATradingFactory tradingFactory = new RWATradingFactory(deployer);
        console.log("- RWATradingFactory:", address(tradingFactory));
        
        console.log("Deploying RWAVaultFactory...");
        RWAVaultFactory vaultFactory = new RWAVaultFactory(deployer);
        console.log("- RWAVaultFactory:", address(vaultFactory));
        
        // Step 2: Deploy coordinator
        console.log("\n--- Step 2: Deploying RWA Coordinator ---");
        RWACoordinator coordinator = new RWACoordinator(
            address(tokenFactory),
            address(tradingFactory),
            address(vaultFactory),
            feeRecipient,
            treasury,
            deployer
        );
        console.log("- RWACoordinator:", address(coordinator));
        
        // Step 3: Transfer factory ownership to coordinator
        console.log("\n--- Step 3: Configuring Factory Ownership ---");
        tokenFactory.transferOwnership(address(coordinator));
        console.log("- TokenFactory ownership transferred to coordinator");
        
        tradingFactory.transferOwnership(address(coordinator));
        console.log("- TradingFactory ownership transferred to coordinator");
        
        vaultFactory.transferOwnership(address(coordinator));
        console.log("- VaultFactory ownership transferred to coordinator");
        
        // Step 4: Deploy dashboard
        console.log("\n--- Step 4: Deploying Dashboard ---");
        RWADashboard dashboard = new RWADashboard(address(coordinator));
        console.log("- RWADashboard:", address(dashboard));
        
        // Step 5: Verify configuration
        console.log("\n--- Step 5: Verifying Configuration ---");
        (address tokenFactoryAddr, address tradingFactoryAddr, address vaultFactoryAddr) = coordinator.getFactories();
        console.log("Coordinator token factory:", tokenFactoryAddr);
        console.log("Coordinator trading factory:", tradingFactoryAddr);
        console.log("Coordinator vault factory:", vaultFactoryAddr);
        
        (address feeRecipientAddr, address treasuryAddr, uint256 nextId) = coordinator.getConfiguration();
        console.log("Coordinator fee recipient:", feeRecipientAddr);
        console.log("Coordinator treasury:", treasuryAddr);
        console.log("Next project ID:", nextId);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("- RWATokenFactory:", address(tokenFactory));
        console.log("- RWATradingFactory:", address(tradingFactory));
        console.log("- RWAVaultFactory:", address(vaultFactory));
        console.log("- RWACoordinator:", address(coordinator));
        console.log("- RWADashboard:", address(dashboard));
        
        console.log("\n=== Modular Architecture Benefits ===");
        console.log("- Each factory is small and focused");
        console.log("- No contract size limitations");
        console.log("- Easy to upgrade individual components");
        console.log("- Clean separation of concerns");
        console.log("- Coordinator orchestrates everything");
        
        console.log("\n=== Explorer Links ===");
        console.log("Token Factory: https://testnet.snowtrace.io/address/", address(tokenFactory));
        console.log("Trading Factory: https://testnet.snowtrace.io/address/", address(tradingFactory));
        console.log("Vault Factory: https://testnet.snowtrace.io/address/", address(vaultFactory));
        console.log("Coordinator: https://testnet.snowtrace.io/address/", address(coordinator));
        console.log("Dashboard: https://testnet.snowtrace.io/address/", address(dashboard));
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify all contracts on Snowtrace");
        console.log("2. Update frontend with coordinator address");
        console.log("3. Create your first RWA project with CreateProjectModular.s.sol");
        console.log("4. Get testnet AVAX from: https://faucet.avax.network/");
        
        // Save deployment info to file
        string memory deploymentInfo = string(abi.encodePacked(
            "Modular RWA Framework Deployment - Avalanche Fuji\n",
            "================================================\n",
            "Network: Avalanche Fuji Testnet\n",
            "Chain ID: ", vm.toString(block.chainid), "\n",
            "Block: ", vm.toString(block.number), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "\nCore Contracts:\n",
            "Coordinator: ", vm.toString(address(coordinator)), "\n",
            "Dashboard: ", vm.toString(address(dashboard)), "\n",
            "\nSpecialized Factories:\n",
            "Token Factory: ", vm.toString(address(tokenFactory)), "\n",
            "Trading Factory: ", vm.toString(address(tradingFactory)), "\n",
            "Vault Factory: ", vm.toString(address(vaultFactory)), "\n",
            "\nExplorer: https://testnet.snowtrace.io/\n",
            "\nArchitecture:\n",
            "- Modular design with specialized factories\n",
            "- Coordinator orchestrates all operations\n",
            "- No contract size limitations\n",
            "- Easy component upgrades\n"
        ));
        
        vm.writeFile("deployment.txt", deploymentInfo);
        console.log("\nDeployment info saved to deployment.txt");
        
        console.log("\n Modular RWA Framework Successfully Deployed! ");
    }
}

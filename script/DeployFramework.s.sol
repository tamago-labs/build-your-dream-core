// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWADashboard.sol";

contract DeployRWAFramework is Script {
    
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
        
        console.log("=== Deploying RWA Framework on Avalanche Fuji ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "AVAX");
        console.log("Chain ID:", block.chainid);
        
        require(deployer.balance > 0.5 ether, "Insufficient AVAX balance for deployment");
        require(block.chainid == 43113, "Must deploy on Avalanche Fuji Testnet (Chain ID: 43113)");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configuration
        address feeRecipient = deployer; // Can be changed later via updateAddresses
        address treasury = deployer; // Can be changed later via updateAddresses 
        
        console.log("Fee recipient:", feeRecipient);
        console.log("Treasury:", treasury); 
        
        // Deploy Factory
        console.log("\n--- Deploying RWAFactory ---");
        RWAFactory factory = new RWAFactory(
            feeRecipient,
            treasury,
            deployer
        );
        
        console.log("RWAFactory deployed at:", address(factory));
        
        // Verify factory configuration
        console.log("Factory owner:", factory.owner()); 
        console.log("Factory fee recipient:", factory.feeRecipient());
        console.log("Factory treasury:", factory.treasury());
        
        // Deploy Dashboard
        console.log("\n--- Deploying RWADashboard ---");
        RWADashboard dashboard = new RWADashboard(address(factory));
        
        console.log("RWADashboard deployed at:", address(dashboard));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("SUCCESS: RWAFactory:", address(factory));
        console.log("SUCCESS: RWADashboard:", address(dashboard)); 
        console.log("SUCCESS: Next project ID:", factory.nextProjectId());
        console.log("Snowtrace: https://testnet.snowtrace.io/address/", address(factory));
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on Snowtrace");
        console.log("2. Update frontend with new addresses");
        console.log("3. Create your first RWA project with CreateProject.s.sol");
        console.log("4. Get testnet AVAX from: https://faucet.avax.network/");
        console.log("5. Configure fee recipient and treasury if needed");
        
        // Save deployment info to file
        string memory deploymentInfo = string(abi.encodePacked(
            "RWA Framework Deployment - Avalanche Fuji\n",
            "=========================================\n",
            "Network: Avalanche Fuji Testnet\n",
            "Chain ID: ", vm.toString(block.chainid), "\n",
            "Block: ", vm.toString(block.number), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "Factory: ", vm.toString(address(factory)), "\n",
            "Dashboard: ", vm.toString(address(dashboard)), "\n", 
            "Explorer: https://testnet.snowtrace.io/\n"
        ));
        
        vm.writeFile("deployment.txt", deploymentInfo);
        console.log("\nDeployment info saved to deployment.txt");
    }
}
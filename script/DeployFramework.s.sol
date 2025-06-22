// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RWAFactory.sol";
import "../src/RWADashboard.sol";

contract DeployRWAFramework is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying RWA Framework ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        
        require(deployer.balance > 0.01 ether, "Insufficient ETH balance for deployment");
        
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
        console.log("RWAFactory:", address(factory));
        console.log("RWADashboard:", address(dashboard)); 
        console.log("Next project ID:", factory.nextProjectId());
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contracts on explorer");
        console.log("2. Update frontend with new addresses");
        console.log("3. Create your first RWA project with CreateProject.s.sol");
        console.log("4. Configure fee recipient and treasury if needed");
        
        // Save deployment info to file
        string memory deploymentInfo = string(abi.encodePacked(
            "RWA Framework Deployment\n",
            "========================\n",
            "Network: ", vm.toString(block.chainid), "\n",
            "Block: ", vm.toString(block.number), "\n",
            "Deployer: ", vm.toString(deployer), "\n",
            "Factory: ", vm.toString(address(factory)), "\n",
            "Dashboard: ", vm.toString(address(dashboard)), "\n"
        ));
        
        vm.writeFile("deployment.txt", deploymentInfo);
        console.log("Deployment info saved to deployment.txt");
    }
}
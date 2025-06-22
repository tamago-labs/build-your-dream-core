// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract VerifySetup is Script {
    
    function run() external view {
        console.log("RWA Framework Setup Verification");
        console.log("====================================");
        
        // Check if we can get environment variables
        try vm.envAddress("FACTORY_ADDRESS") returns (address factory) {
            console.log("FACTORY_ADDRESS found:", factory);
        } catch {
            console.log("FACTORY_ADDRESS not set (normal if not deployed yet)");
        }
        
        try vm.envAddress("DASHBOARD_ADDRESS") returns (address dashboard) {
            console.log("DASHBOARD_ADDRESS found:", dashboard);
        } catch {
            console.log("DASHBOARD_ADDRESS not set (normal if not deployed yet)");
        }
        
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            address deployer = vm.addr(pk);
            console.log("PRIVATE_KEY configured");
            console.log("Deployer address:", deployer);
        } catch {
            console.log("PRIVATE_KEY not set in .env");
        }
        
        try vm.envString("SEPOLIA_RPC_URL") returns (string memory rpc) {
            console.log("SEPOLIA_RPC_URL configured");
        } catch {
            console.log("SEPOLIA_RPC_URL not set");
        }
        
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpc) {
            console.log("MAINNET_RPC_URL configured");
        } catch {
            console.log("MAINNET_RPC_URL not set");
        }
        
        try vm.envString("ETHERSCAN_API_KEY") returns (string memory key) {
            console.log("ETHERSCAN_API_KEY configured");
        } catch {
            console.log("ETHERSCAN_API_KEY not set (verification will fail)");
        }
        
        console.log("Setup Checklist:");
        console.log("==================");
        console.log("1. Copy .env.example to .env");
        console.log("2. Set PRIVATE_KEY in .env");
        console.log("3. Set RPC URLs (Sepolia/Mainnet)");
        console.log("4. Set ETHERSCAN_API_KEY for verification");
        console.log("5. Fund deployer account with ETH");
        
        console.log("Ready to Deploy:");
        console.log("==================");
        console.log("# Make deploy script executable:");
        console.log("chmod +x script/deploy.sh");
        console.log("");
        console.log("# Run interactive deployment:");
        console.log("./script/deploy.sh");
        console.log("");
        console.log("# Or deploy manually:");
        console.log("forge script script/DeployFramework.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify");
        
        console.log("Available Scripts:");
        console.log("====================");
        console.log("DeployFramework.s.sol - Deploy core framework");
        console.log("CreateProject.s.sol   - Create RWA projects");
        console.log("ManageProject.s.sol   - Manage projects");
        console.log("ViewProjects.s.sol    - View all projects");
        console.log("deploy.sh             - Interactive deployment");
        console.log("VerifySetup.s.sol     - This verification script");
    }
}
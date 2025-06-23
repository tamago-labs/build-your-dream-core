// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract VerifySetup is Script {
    
    function run() external view {
        console.log("RWA Framework Setup Verification - Avalanche Fuji");
        console.log("=====================================================");
        
        // Check current network
        uint256 chainId = block.chainid;
        console.log("Current Chain ID:", chainId);
        
        if (chainId == 43113) {
            console.log("SUCCESS: Connected to Avalanche Fuji Testnet");
        } else {
            console.log("ERROR: Wrong network! Expected Avalanche Fuji (43113), got:", chainId);
        }
        
        // Check if we can get environment variables
        try vm.envAddress("FACTORY_ADDRESS") returns (address factory) {
            console.log("SUCCESS: FACTORY_ADDRESS found:", factory);
            console.log("Snowtrace: https://testnet.snowtrace.io/address/", factory);
        } catch {
            console.log("WARNING: FACTORY_ADDRESS not set (normal if not deployed yet)");
        }
        
        try vm.envAddress("DASHBOARD_ADDRESS") returns (address dashboard) {
            console.log("SUCCESS: DASHBOARD_ADDRESS found:", dashboard);
            console.log("Snowtrace: https://testnet.snowtrace.io/address/", dashboard);
        } catch {
            console.log("WARNING: DASHBOARD_ADDRESS not set (normal if not deployed yet)");
        }
        
        try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
            address deployer = vm.addr(pk);
            console.log("SUCCESS: PRIVATE_KEY configured");
            console.log("   Deployer address:", deployer);
            
            // Check AVAX balance
            uint256 balance = deployer.balance;
            console.log("   AVAX balance:", balance / 1e18, "AVAX");
            
            if (balance < 0.5 ether) {
                console.log("WARNING: Low AVAX balance! Recommend at least 1 AVAX for deployment");
                console.log("Get testnet AVAX: https://faucet.avax.network/");
            } else {
                console.log("SUCCESS: Sufficient AVAX balance for deployment");
            }
        } catch {
            console.log("ERROR: PRIVATE_KEY not set in .env");
        }
        
        try vm.envString("FUJI_RPC_URL") returns (string memory rpc) {
            console.log("SUCCESS: FUJI_RPC_URL configured");
            console.log("   RPC:", rpc);
        } catch {
            console.log("ERROR: FUJI_RPC_URL not set");
            console.log("   Add: FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc");
        }
        
        try vm.envString("SNOWTRACE_API_KEY") returns (string memory key) {
            console.log("SUCCESS: SNOWTRACE_API_KEY configured");
        } catch {
            console.log("WARNING: SNOWTRACE_API_KEY not set (verification will fail)");
            console.log("   Get API key: https://snowtrace.io/apis");
        }
        
        console.log("\nAvalanche Setup Checklist:");
        console.log("=============================");
        console.log("1. Copy .env.example to .env");
        console.log("2. Set PRIVATE_KEY in .env");
        console.log("3. Set FUJI_RPC_URL for Avalanche Fuji testnet");
        console.log("4. Set SNOWTRACE_API_KEY for contract verification");
        console.log("5. Fund deployer account with testnet AVAX");
        console.log("6. Ensure connected to Fuji network (Chain ID: 43113)");
        
        console.log("\nAvalanche Fuji Testnet Info:");
        console.log("===============================");
        console.log("Chain ID: 43113");
        console.log("RPC URL: https://api.avax-test.network/ext/bc/C/rpc");
        console.log("Explorer: https://testnet.snowtrace.io/");
        console.log("Faucet: https://faucet.avax.network/");
        console.log("Native Token: AVAX");
        
        console.log("\nReady to Deploy:");
        console.log("==================");
        console.log("# Make deploy script executable:");
        console.log("chmod +x script/deploy.sh");
        console.log("");
        console.log("# Run interactive deployment:");
        console.log("./script/deploy.sh");
        console.log("");
        console.log("# Or deploy manually:");
        console.log("forge script script/DeployFramework.s.sol --rpc-url $FUJI_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify");
        
        console.log("\nAvailable Scripts:");
        console.log("====================");
        console.log("-DeployFramework.s.sol - Deploy core framework");
        console.log("- CreateProject.s.sol   - Create RWA projects");
        console.log("- ManageProject.s.sol   - Manage projects");
        console.log("- ViewProjects.s.sol    - View all projects");
        console.log("- deploy.sh             - Interactive deployment");
        console.log("- VerifySetup.s.sol     - This verification script");
        
        console.log("\nPro Tips:");
        console.log("============");
        console.log("- Start with testnet deployment to test everything");
        console.log("- Get plenty of testnet AVAX from the faucet");
        console.log("- Verify contracts for better transparency");
        console.log("- Use Snowtrace to monitor transactions");
    }
}
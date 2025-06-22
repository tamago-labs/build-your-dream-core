// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RWAFactory.sol";
import "../src/RWAToken.sol";
import "../src/RWAPrimarySales.sol";
import "../src/RWARFQ.sol";
import "../src/RWAVault.sol";
import "../src/RWADashboard.sol";

contract RWAIntegrationTest is Test {
    
    RWAFactory public factory;
    RWADashboard public dashboard;
    
    address public owner = address(0x1);
    address public treasury = address(0x2);
    address public feeRecipient = address(0x3);
    address public projectWallet = address(0x4);
    address public user1 = address(0x5);
    address public user2 = address(0x6);
    
    uint256 public constant CREATION_FEE = 0.1 ether;
    
    function setUp() public {
        vm.startPrank(owner);
        
        factory = new RWAFactory(feeRecipient, treasury, owner);
        dashboard = new RWADashboard(address(factory));
        
        vm.stopPrank();
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(projectWallet, 10 ether);
    }
    
    function testCreateRWAProject() public {
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Luxury apartment building in NYC",
            totalValue: 50_000_000 * 1e8, // $50M with 8 decimals
            url: "https://example.com/property",
            createdAt: 0 // Will be set by contract
        });
        
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        
        uint256 projectId = factory.createRWAProject{value: CREATION_FEE}(
            "NYC Real Estate Token",
            "NYCRE",
            metadata,
            projectWallet,
            20, // 20% to project
            0.001 ether // 0.001 ETH per token
        );
        
        vm.stopPrank();
        
        assertEq(projectId, 1);
        
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        assertEq(project.creator, user1);
        assertTrue(project.isActive);
        assertTrue(project.rwaToken != address(0));
        assertTrue(project.primarySales != address(0));
        assertTrue(project.rfq != address(0));
        assertTrue(project.vault != address(0));
    }
    
    function testPrimaryTradingFlow() public {
        // Create project
        uint256 projectId = _createTestProject();
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        
        RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
        RWAToken token = RWAToken(project.rwaToken);
        
        // Whitelist user
        vm.prank(user1);
        address[] memory users = new address[](1);
        users[0] = user2;
        sales.whitelistUsers(users, true);
        
        // User purchases tokens
        vm.startPrank(user2);
        uint256 purchaseAmount = 10 ether;
        sales.purchaseTokens{value: purchaseAmount}();
        
        uint256 expectedTokens = sales.getTokensForETH(purchaseAmount);
        assertEq(token.balanceOf(user2), expectedTokens);
        assertEq(sales.purchased(user2), purchaseAmount);
        
        vm.stopPrank();
    }
    
    function testRFQTrading() public {
        console.log("=== Starting RFQ Trading Test ===");
        uint256 projectId = _createTestProject();
        console.log("Project created with ID:", projectId);
        
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        console.log("Got project data");
        
        RWARFQ rfq = RWARFQ(project.rfq);
        RWAToken token = RWAToken(project.rwaToken);
        console.log("RFQ address:", address(rfq));
        console.log("Token address:", address(token));
        
        // First give users some tokens
        console.log("Setting up token balances...");
        _setupTokenBalances(project, user1, user2);
        
        uint256 user1Balance = token.balanceOf(user1);
        uint256 user2Balance = token.balanceOf(user2);
        console.log("User1 token balance:", user1Balance);
        console.log("User2 token balance:", user2Balance);
        
        // User1 submits sell quote
        console.log("User1 submitting sell quote...");
        vm.startPrank(user1);
        uint256 sellAmount = 1000 * 1e18;
        uint256 pricePerToken = 0.002 ether;
        
        console.log("Sell amount:", sellAmount);
        console.log("Price per token:", pricePerToken);
        
        if (user1Balance < sellAmount) {
            console.log("ERROR: User1 doesn't have enough tokens!");
            console.log("Required:", sellAmount);
            console.log("Available:", user1Balance);
            revert("Insufficient tokens for test");
        }
        
        console.log("Approving RFQ to spend tokens...");
        token.approve(address(rfq), sellAmount);
        
        console.log("Submitting quote...");
        try rfq.submitQuote(
            false, // selling
            sellAmount,
            pricePerToken,
            1 hours,
            "Selling 1000 tokens"
        ) {
            console.log("Quote submitted successfully");
        } catch Error(string memory reason) {
            console.log("Quote submission failed:", reason);
            revert(reason);
        }
        vm.stopPrank();
        
        // Check if quote exists
        try rfq.quotes(0) returns (
            address maker,
            bool isBuyQuote,
            uint256 amount,
            uint256 pricePerToken,
            uint256 expiry,
            bool isActive,
            string memory description
        ) {
            console.log("Quote created - ID: 0");
            console.log("Quote maker:", maker);
            console.log("Quote amount:", amount);
            console.log("Quote active:", isActive);
        } catch {
            console.log("ERROR: Quote 0 does not exist!");
            revert("Quote was not created");
        }
        
        // User2 accepts the quote
        console.log("User2 accepting quote...");
        vm.startPrank(user2);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        uint256 totalCost = (sellAmount * pricePerToken) / 1e18;
        
        console.log("Total cost for user2:", totalCost);
        console.log("User2 ETH balance:", user2.balance);
        
        if (user2.balance < totalCost) {
            console.log("ERROR: User2 doesn't have enough ETH!");
            console.log("Required:", totalCost);
            console.log("Available:", user2.balance);
            revert("Insufficient ETH for test");
        }
        
        try rfq.acceptQuote{value: totalCost}(0) {
            console.log("Quote accepted successfully");
        } catch Error(string memory reason) {
            console.log("Quote acceptance failed:", reason);
            revert(reason);
        }
        
        uint256 user2BalanceAfter = token.balanceOf(user2);
        console.log("User2 balance before:", user2BalanceBefore);
        console.log("User2 balance after:", user2BalanceAfter);
        console.log("Expected increase:", sellAmount);
        
        assertEq(user2BalanceAfter - user2BalanceBefore, sellAmount);
        console.log("=== RFQ Trading Test Completed ===");
        vm.stopPrank();
    }
    
    function testVaultStaking() public {
        console.log("=== Starting Vault Staking Test ===");
        uint256 projectId = _createTestProject();
        console.log("Project created with ID:", projectId);
        
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        console.log("Got project data");
        
        RWAVault vault = RWAVault(payable(project.vault));
        RWAToken token = RWAToken(project.rwaToken);
        console.log("Vault address:", address(vault));
        console.log("Token address:", address(token));
        console.log("Vault owner:", vault.owner());
        console.log("Vault reward distributor:", vault.rewardDistributor());
        console.log("User1 address:", user1);
        
        // Give user tokens
        console.log("Setting up token balances...");
        _setupTokenBalances(project, user1, user2);
        
        uint256 user1Balance = token.balanceOf(user1);
        console.log("User1 token balance:", user1Balance);
        
        // User stakes tokens first
        console.log("User1 staking tokens...");
        vm.startPrank(user1);
        uint256 stakeAmount = 1000 * 1e18;
        console.log("Stake amount:", stakeAmount);
        
        if (user1Balance < stakeAmount) {
            console.log("ERROR: User1 doesn't have enough tokens to stake!");
            console.log("Required:", stakeAmount);
            console.log("Available:", user1Balance);
            revert("Insufficient tokens for staking test");
        }
        
        console.log("Approving vault to spend tokens...");
        token.approve(address(vault), stakeAmount);
        
        console.log("Calling vault.stake()...");
        try vault.stake(stakeAmount) {
            console.log("Stake successful");
        } catch Error(string memory reason) {
            console.log("Stake failed:", reason);
            revert(reason);
        }
        
        (uint256 stakedAmount,,) = vault.getUserStakeInfo(user1);
        console.log("Staked amount:", stakedAmount);
        assertTrue(stakedAmount > 0);
        
        uint256 totalStaked = vault.totalStaked();
        console.log("Total staked in vault:", totalStaked);
        
        // Now distribute rewards (user1 is project creator and vault owner)
        console.log("Distributing rewards...");
        vm.deal(user1, 10 ether);
        console.log("User1 ETH balance:", user1.balance);
        
        try vault.distributeRewards{value: 1 ether}("Q1 2024 rental income") {
            console.log("Rewards distributed successfully");
        } catch Error(string memory reason) {
            console.log("Rewards distribution failed:", reason);
            revert(reason);
        }
        vm.stopPrank();
        
        // Check pending rewards
        console.log("Checking pending rewards...");
        uint256 pendingRewards = vault.getPendingRewards(user1);
        console.log("Pending rewards:", pendingRewards);
        assertTrue(pendingRewards > 0);
        
        // Claim rewards
        console.log("Claiming rewards...");
        vm.prank(user1);
        try vault.claimRewards() {
            console.log("Rewards claimed successfully");
        } catch Error(string memory reason) {
            console.log("Claim rewards failed:", reason);
            revert(reason);
        }
        
        console.log("=== Vault Staking Test Completed ===");
    }
    
    function testDashboardIntegration() public {
        uint256 projectId = _createTestProject();
        
        // Get project overview
        RWADashboard.ProjectOverview memory overview = dashboard.getProjectOverview(projectId);
        
        assertEq(overview.projectId, projectId);
        assertEq(overview.creator, user1);
        assertTrue(overview.isActive);
        assertEq(overview.name, "Test RWA Token");
        assertEq(overview.symbol, "TRWA");
        assertEq(overview.assetType, "real-estate");
        
        // Get user data
        RWADashboard.UserProjectData memory userData = dashboard.getUserProjectData(projectId, user2);
        
        // Initially user should have no data
        assertEq(userData.tokenBalance, 0);
        assertEq(userData.purchasedAmount, 0);
        assertFalse(userData.isWhitelisted);
    }
    
    function testFactoryStats() public {
        _createTestProject();
        _createTestProject();
        
        (uint256 totalProjects, uint256 creationFee, address feeRec, address treas) = dashboard.getFactoryStats();
        
        assertEq(totalProjects, 2);
        assertEq(creationFee, CREATION_FEE);
        assertEq(feeRec, feeRecipient);
        assertEq(treas, treasury);
    }
    
    function _createTestProject() internal returns (uint256) {
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Test property",
            totalValue: 10_000_000 * 1e8,
            url: "https://test.com",
            createdAt: 0
        });
        
        vm.startPrank(user1);
        // Give user1 enough ETH for creation fee + token purchases
        vm.deal(user1, 20 ether); // Increased from 1 ether
        
        uint256 projectId = factory.createRWAProject{value: CREATION_FEE}(
            "Test RWA Token",
            "TRWA",
            metadata,
            projectWallet,
            15,
            0.001 ether
        );
        
        vm.stopPrank();
        return projectId;
    }
    
    function _setupTokenBalances(RWAFactory.RWAProject memory project, address user_1, address user_2) internal {
        console.log("--- Setting up token balances ---");
        RWAToken token = RWAToken(project.rwaToken);
        RWAPrimarySales sales = RWAPrimarySales(project.primarySales);
        
        console.log("Token address:", address(token));
        console.log("Primary sales address:", address(sales));
        console.log("Sales owner:", sales.owner());
        console.log("User1 (caller):", user_1);
        
        // Whitelist users
        console.log("Whitelisting users...");
        vm.startPrank(user_1);
        address[] memory users = new address[](2);
        users[0] = user_1;
        users[1] = user_2;
        
        try sales.whitelistUsers(users, true) {
            console.log("Users whitelisted successfully");
        } catch Error(string memory reason) {
            console.log("Whitelisting failed:", reason);
            revert(reason);
        }
        vm.stopPrank();
        
        console.log("User1 whitelisted:", sales.whitelisted(user_1));
        console.log("User2 whitelisted:", sales.whitelisted(user_2));
        
        // Users buy tokens
        console.log("User1 purchasing tokens with 5 ETH...");
        vm.startPrank(user_1);
        console.log("User1 ETH balance:", user_1.balance);
        console.log("Price per token:", sales.pricePerTokenETH());
        console.log("Expected tokens from 5 ETH:", sales.getTokensForETH(5 ether));
        
        try sales.purchaseTokens{value: 5 ether}() {
            console.log("User1 purchase successful");
        } catch Error(string memory reason) {
            console.log("User1 purchase failed:", reason);
            revert(reason);
        }
        
        uint256 user1TokenBalance = token.balanceOf(user_1);
        console.log("User1 token balance after purchase:", user1TokenBalance);
        vm.stopPrank();
        
        console.log("User2 purchasing tokens with 3 ETH...");
        vm.startPrank(user_2);
        console.log("User2 ETH balance:", user_2.balance);
        console.log("Expected tokens from 3 ETH:", sales.getTokensForETH(3 ether));
        
        try sales.purchaseTokens{value: 3 ether}() {
            console.log("User2 purchase successful");
        } catch Error(string memory reason) {
            console.log("User2 purchase failed:", reason);
            revert(reason);
        }
        
        uint256 user2TokenBalance = token.balanceOf(user_2);
        console.log("User2 token balance after purchase:", user2TokenBalance);
        vm.stopPrank();
        
        console.log("--- Token balance setup completed ---");
    }
}
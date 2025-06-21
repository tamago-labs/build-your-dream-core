// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RWAToken.sol";
import "../src/RWAFactory.sol";
import "../src/RWAOrderbook.sol";
import "../src/RWAVault.sol";

/**
 * @title RWAIntegrationTest
 * @notice Integration tests showing the complete RWA tokenization flow
 */
contract RWAIntegrationTest is Test {
    RWAFactory public factory;
    RWAToken public rwaToken;
    RWAOrderbook public orderbook;
    RWAVault public vault;
    
    address public factoryOwner = address(0x1);
    address public projectCreator = address(0x2);
    address public projectWallet = address(0x3);
    address public trader1 = address(0x4);
    address public trader2 = address(0x5);
    address public feeRecipient = address(0x6);
    address public treasury = address(0x7);
    
    uint256 public constant INITIAL_PRICE = 0.01 ether; // 0.01 ETH per token
    
    function setUp() public {
        // Setup accounts with ETH
        vm.deal(factoryOwner, 100 ether);
        vm.deal(projectCreator, 50 ether);
        vm.deal(projectWallet, 10 ether);
        vm.deal(trader1, 20 ether);
        vm.deal(trader2, 20 ether);
        
        // Deploy factory
        vm.prank(factoryOwner);
        factory = new RWAFactory(
            feeRecipient,
            treasury,
            factoryOwner
        );
    }
    
    function testCompleteRWAFlow() public {
        // 1. Create RWA project
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Premium office building in Tokyo",
            totalValue: 50_000_000 * 10**8, // $50M
            url: "https://example.com/tokyo-office",
            createdAt: 0
        });
        
        vm.prank(projectCreator);
        uint256 projectId = factory.createRWAProject(
            "Tokyo Office Token",
            "TOT",
            metadata,
            projectWallet,
            10, // 10% to project, 90% to liquidity
            INITIAL_PRICE
        );
        
        // Get deployed contracts
        RWAFactory.RWAProject memory project = factory.getProject(projectId);
        rwaToken = RWAToken(payable(project.rwaToken));
        orderbook = RWAOrderbook(payable(project.orderbook));
        vault = RWAVault(project.vault);
        
        // 2. Verify initial state
        assertEq(rwaToken.name(), "Tokyo Office Token");
        assertEq(rwaToken.symbol(), "TOT");
        assertEq(rwaToken.projectWallet(), projectWallet);
        assertEq(rwaToken.projectAllocationPercent(), 10);
        
        // Project should have 10% of tokens
        uint256 totalSupply = rwaToken.totalSupply();
        uint256 expectedProjectTokens = (totalSupply * 10) / 100;
        assertEq(rwaToken.balanceOf(projectWallet), expectedProjectTokens);
        
        // Orderbook should have liquidity tokens
        uint256 expectedLiquidityTokens = totalSupply - expectedProjectTokens;
        assertEq(rwaToken.balanceOf(address(orderbook)), expectedLiquidityTokens);
        
        // Verify initial liquidity allocation tracking
        assertEq(rwaToken.getInitialLiquidityAllocation(), expectedLiquidityTokens);
        assertEq(rwaToken.getAvailableLiquidityTokens(), 0); // All transferred to orderbook
        
        // 3. Test trading - Buy tokens
        uint256 buyAmount = 1000 * 10**18; // Buy 1000 tokens
        uint256 totalCost = (buyAmount * INITIAL_PRICE) / 1e18;
        
        vm.prank(trader1);
        orderbook.placeBuyOrder{value: totalCost}(buyAmount, INITIAL_PRICE);
        
        // Trader1 should have received tokens
        assertGt(rwaToken.balanceOf(trader1), 0);
        console.log("Trader1 RWA balance:", rwaToken.balanceOf(trader1));

        // 4. Test vault staking
        uint256 stakeAmount = rwaToken.balanceOf(trader1) / 2;
        
        vm.startPrank(trader1);
        rwaToken.transfer(trader2, 100 * 10**18);
        rwaToken.approve(address(vault), stakeAmount);
        vault.deposit(stakeAmount);
        vm.stopPrank();
        
        // Check vault state
        (uint256 shares, uint256 rewardDebt, uint256 depositTime) = vault.userInfo(trader1);
        assertGt(shares, 0);
        assertEq(vault.getUserTokenAmount(trader1), stakeAmount);
        
        // 5. Test project distributing rewards
        uint256 rewardAmount = 1000 * 10**18;
        
        vm.startPrank(projectWallet);
        rwaToken.approve(address(vault), rewardAmount);
        vault.addRewards(rewardAmount);
        vm.stopPrank();
        
        // 6. Test claiming rewards
        uint256 pendingRewards = vault.pendingRewards(trader1);
        assertGt(pendingRewards, 0);
        
        vm.prank(trader1);
        vault.claimRewards(); 
        vm.stopPrank();
        
        // 7. Test selling tokens
        uint256 sellAmount = 100 * 10**18;
        uint256 sellPrice = INITIAL_PRICE + (INITIAL_PRICE / 10); // 10% higher
        
        vm.startPrank(trader2);
        rwaToken.approve(address(orderbook), sellAmount);
        orderbook.placeSellOrder(sellAmount, sellPrice);
        vm.stopPrank();
        
        // 8. Test asset metadata update
        RWAToken.AssetMetadata memory newMetadata = metadata;
        newMetadata.totalValue = 55_000_000 * 10**8; // $55M (10% increase)
        newMetadata.description = "Premium office building in Tokyo - Recently renovated";
        
        vm.prank(projectCreator);
        rwaToken.updateAssetMetadata(newMetadata);
        
        // Verify update
        (, string memory updatedDescription, uint256 updatedTotalValue, ,) = rwaToken.assetData();
        assertEq(updatedTotalValue, 55_000_000 * 10**8);
        assertEq(updatedDescription, "Premium office building in Tokyo - Recently renovated");
        
        // 9. Verify final state
        console.log("=== Final State ===");
        console.log("Total Supply:", rwaToken.totalSupply());
        console.log("Project Balance:", rwaToken.balanceOf(projectWallet));
        console.log("Trader1 Balance:", rwaToken.balanceOf(trader1));
        console.log("Vault Total Staked:", vault.totalStaked());
        console.log("Asset Market Cap:", rwaToken.getMarketCap());
        console.log("Price Per Token:", rwaToken.getPricePerToken());
        
        // Verify invariants
        assertTrue(rwaToken.totalSupply() > 0);
        assertTrue(rwaToken.getMarketCap() > 0);
        assertTrue(rwaToken.getPricePerToken() > 0);
    }
    
    function testMultipleProjectCreation() public {
        // Create multiple RWA projects to test factory functionality
        
        // Project 1: Real Estate
        RWAToken.AssetMetadata memory realEstateMetadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Shopping mall in Seoul",
            totalValue: 30_000_000 * 10**8,
            url: "https://example.com/seoul-mall",
            createdAt: 0
        });
        
        vm.prank(projectCreator);
        uint256 project1Id = factory.createRWAProject(
            "Seoul Mall Token",
            "SMT",
            realEstateMetadata,
            projectWallet,
            15, // 15% allocation
            0.02 ether
        );
        
        // Project 2: Art
        RWAToken.AssetMetadata memory artMetadata = RWAToken.AssetMetadata({
            assetType: "art",
            description: "Contemporary art collection",
            totalValue: 5_000_000 * 10**8,
            url: "https://example.com/art-collection",
            createdAt: 0
        });
        
        vm.prank(projectCreator);
        uint256 project2Id = factory.createRWAProject(
            "Art Collection Token",
            "ACT",
            artMetadata,
            projectWallet,
            25, // 25% allocation
            0.005 ether
        );
        
        // Verify both projects exist
        RWAFactory.RWAProject memory project1 = factory.getProject(project1Id);
        RWAFactory.RWAProject memory project2 = factory.getProject(project2Id);
        
        assertEq(project1.creator, projectCreator);
        assertEq(project2.creator, projectCreator);
        assertTrue(project1.isActive);
        assertTrue(project2.isActive);
        
        // Check tokens
        RWAToken token1 = RWAToken(payable(project1.rwaToken));
        RWAToken token2 = RWAToken(payable(project2.rwaToken));
        
        assertEq(token1.name(), "Seoul Mall Token");
        assertEq(token2.name(), "Art Collection Token");
        assertEq(token1.projectAllocationPercent(), 15);
        assertEq(token2.projectAllocationPercent(), 25);
        
        // Verify creator projects mapping
        uint256[] memory creatorProjects = factory.getCreatorProjects(projectCreator);
        assertEq(creatorProjects.length, 2);
        assertEq(creatorProjects[0], project1Id);
        assertEq(creatorProjects[1], project2Id);
        
        console.log("=== Multiple Projects Test ===");
        console.log("Project 1 ID:", project1Id);
        console.log("Project 1 Token:", project1.rwaToken);
        console.log("Project 2 ID:", project2Id);
        console.log("Project 2 Token:", project2.rwaToken);
    }
    
    function testErrorConditions() public {
        // Test various error conditions
        
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Test property",
            totalValue: 1_000_000 * 10**8,
            url: "https://example.com/test",
            createdAt: 0
        });
        
        // Should fail with empty name
        vm.expectRevert("Name required");
        vm.prank(projectCreator);
        factory.createRWAProject(
            "",
            "TEST",
            metadata,
            projectWallet,
            10,
            INITIAL_PRICE
        );
        
        // Should fail with empty symbol
        vm.expectRevert("Symbol required");
        vm.prank(projectCreator);
        factory.createRWAProject(
            "Test Token",
            "",
            metadata,
            projectWallet,
            10,
            INITIAL_PRICE
        );
        
        // Should fail with zero address project wallet
        vm.expectRevert("Invalid project wallet");
        vm.prank(projectCreator);
        factory.createRWAProject(
            "Test Token",
            "TEST",
            metadata,
            address(0),
            10,
            INITIAL_PRICE
        );
        
        // Should fail with zero initial price
        vm.expectRevert("Initial price required");
        vm.prank(projectCreator);
        factory.createRWAProject(
            "Test Token",
            "TEST",
            metadata,
            projectWallet,
            10,
            0
        );
    }
}
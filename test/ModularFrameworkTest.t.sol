// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../src/factories/RWATokenFactory.sol";
import "../src/factories/RWATradingFactory.sol";
import "../src/factories/RWAVaultFactory.sol";
import "../src/RWACoordinator.sol";
import "../src/RWAToken.sol";
import "../src/RWAPrimarySales.sol";
import "../src/RWARFQ.sol";
import "../src/RWAVault.sol";

contract ModularFrameworkTest is Test {
    RWATokenFactory tokenFactory;
    RWATradingFactory tradingFactory;
    RWAVaultFactory vaultFactory;
    RWACoordinator coordinator;
    
    address owner = address(0x123);
    address creator = address(0x456);
    address treasury = address(0x789);
    address feeRecipient = address(0xabc);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy specialized factories
        tokenFactory = new RWATokenFactory(owner);
        tradingFactory = new RWATradingFactory(owner);
        vaultFactory = new RWAVaultFactory(owner);
        
        // Deploy coordinator
        coordinator = new RWACoordinator(
            address(tokenFactory),
            address(tradingFactory),
            address(vaultFactory),
            feeRecipient,
            treasury,
            owner
        );
        
        // Transfer factory ownership to coordinator
        tokenFactory.transferOwnership(address(coordinator));
        tradingFactory.transferOwnership(address(coordinator));
        vaultFactory.transferOwnership(address(coordinator));
        
        vm.stopPrank();
    }
    
    function testModularDeployment() public {
        vm.startPrank(creator);
        vm.deal(creator, 10 ether);
        
        // Create asset metadata
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "real-estate",
            description: "Test property for modular deployment",
            totalValue: 1000000 * 1e8,
            url: "https://test.com",
            createdAt: 0
        });
        
        // Create complete project
        uint256 projectId = coordinator.createRWAProject(
            "Test Modular Token",
            "TMT",
            metadata,
            creator,
            10, // 10% allocation
            0.001 ether
        );
        
        // Verify project creation
        assertEq(projectId, 1);
        
        RWACoordinator.RWAProject memory project = coordinator.getProject(projectId);
        assertTrue(project.rwaToken != address(0));
        assertTrue(project.primarySales != address(0));
        assertTrue(project.rfq != address(0));
        assertTrue(project.vault != address(0));
        assertEq(project.creator, creator);
        assertTrue(project.isActive);
        
        // Verify token configuration
        RWAToken token = RWAToken(project.rwaToken);
        assertEq(token.name(), "Test Modular Token");
        assertEq(token.symbol(), "TMT");
        assertEq(token.owner(), creator);
        assertEq(token.projectAllocationPercent(), 10);
        
        // Verify primary sales configuration
        RWAPrimarySales primarySales = RWAPrimarySales(project.primarySales);
        assertEq(address(primarySales.rwaToken()), project.rwaToken);
        assertEq(primarySales.pricePerTokenETH(), 0.001 ether);
        
        // Verify RFQ configuration
        RWARFQ rfq = RWARFQ(project.rfq);
        assertEq(address(rfq.rwaToken()), project.rwaToken);
        
        // Verify vault configuration
        RWAVault vault = RWAVault(payable(project.vault));
        assertEq(address(vault.rwaToken()), project.rwaToken);
        
        vm.stopPrank();
    }
    
    function testFactoryAddresses() public {
        (address tokenFactoryAddr, address tradingFactoryAddr, address vaultFactoryAddr) = coordinator.getFactories();
        
        assertEq(tokenFactoryAddr, address(tokenFactory));
        assertEq(tradingFactoryAddr, address(tradingFactory));
        assertEq(vaultFactoryAddr, address(vaultFactory));
    }
    
    function testConfiguration() public {
        (address feeRecipientAddr, address treasuryAddr, uint256 nextId) = coordinator.getConfiguration();
        
        assertEq(feeRecipientAddr, feeRecipient);
        assertEq(treasuryAddr, treasury);
        assertEq(nextId, 1);
    }
    
    function testProjectStats() public {
        vm.startPrank(creator);
        
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "test",
            description: "Test",
            totalValue: 1000000 * 1e8,
            url: "https://test.com",
            createdAt: 0
        });
        
        // Create multiple projects
        coordinator.createRWAProject("Test1", "T1", metadata, creator, 10, 0.001 ether);
        coordinator.createRWAProject("Test2", "T2", metadata, creator, 15, 0.002 ether);
        
        vm.stopPrank();
        
        (uint256 totalProjects, uint256 activeProjects) = coordinator.getProjectStats();
        assertEq(totalProjects, 2);
        assertEq(activeProjects, 2);
        
        // Deactivate one project
        vm.prank(owner);
        coordinator.deactivateProject(1);
        
        (totalProjects, activeProjects) = coordinator.getProjectStats();
        assertEq(totalProjects, 2);
        assertEq(activeProjects, 1);
    }
    
    function testCreatorProjects() public {
        vm.startPrank(creator);
        
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "test",
            description: "Test",
            totalValue: 1000000 * 1e8,
            url: "https://test.com",
            createdAt: 0
        });
        
        coordinator.createRWAProject("Test1", "T1", metadata, creator, 10, 0.001 ether);
        coordinator.createRWAProject("Test2", "T2", metadata, creator, 15, 0.002 ether);
        
        vm.stopPrank();
        
        uint256[] memory projects = coordinator.getCreatorProjects(creator);
        assertEq(projects.length, 2);
        assertEq(projects[0], 1);
        assertEq(projects[1], 2);
    }
    
    function testUpdateAddresses() public {
        address newFeeRecipient = address(0xdef);
        address newTreasury = address(0x999);
        
        vm.prank(owner);
        coordinator.updateAddresses(newFeeRecipient, newTreasury);
        
        (address feeRecipientAddr, address treasuryAddr,) = coordinator.getConfiguration();
        assertEq(feeRecipientAddr, newFeeRecipient);
        assertEq(treasuryAddr, newTreasury);
    }
    
    function testCannotUpdateAddressesNonOwner() public {
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator));
        coordinator.updateAddresses(address(0x123), address(0x456));
    }
    
    function testCannotCreateProjectWithInvalidParams() public {
        vm.startPrank(creator);
        
        RWAToken.AssetMetadata memory metadata = RWAToken.AssetMetadata({
            assetType: "test",
            description: "Test",
            totalValue: 1000000 * 1e8,
            url: "https://test.com",
            createdAt: 0
        });
        
        // Empty name
        vm.expectRevert("Name required");
        coordinator.createRWAProject("", "TEST", metadata, creator, 10, 0.001 ether);
        
        // Empty symbol
        vm.expectRevert("Symbol required");
        coordinator.createRWAProject("Test", "", metadata, creator, 10, 0.001 ether);
        
        // Invalid wallet
        vm.expectRevert("Invalid project wallet");
        coordinator.createRWAProject("Test", "TEST", metadata, address(0), 10, 0.001 ether);
        
        // Zero price
        vm.expectRevert("Price required");
        coordinator.createRWAProject("Test", "TEST", metadata, creator, 10, 0);
        
        // Invalid allocation
        vm.expectRevert("Invalid allocation");
        coordinator.createRWAProject("Test", "TEST", metadata, creator, 101, 0.001 ether);
        
        vm.stopPrank();
    }
}

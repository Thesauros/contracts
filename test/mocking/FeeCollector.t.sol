// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {FeeCollector} from "../../contracts/FeeCollector.sol";
import {Rebalancer} from "../../contracts/Rebalancer.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockProviderA as MockProvider} from "../../contracts/mocks/MockProvider.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";

contract FeeCollectorTest is Test {
    FeeCollector public feeCollector;
    Rebalancer public vault;
    MockERC20 public asset;
    MockProvider public mockProvider;
    
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public treasury = makeAddr("treasury");
    
    uint256 public constant DEPOSIT_AMOUNT = 10000 ether;
    uint256 public constant FEE_AMOUNT = 100 ether;
    uint256 public constant COLLECTION_INTERVAL = 7 days;
    
    bytes32 public constant ADMIN_ROLE = 0x00;
    
    event VaultRegistered(address indexed vault, uint256 collectionInterval);
    event FeesCollected(address indexed vault, address indexed asset, uint256 amount);
    event TreasuryUpdated(address indexed newTreasury);
    
    function setUp() public {
        // Deploy mock asset
        asset = new MockERC20("Test USDC", "tUSDC", 18);
        
        // Deploy mock provider
        mockProvider = new MockProvider();
        
        // Deploy vault
        IProvider[] memory providers = new IProvider[](1);
        providers[0] = mockProvider;
        
        vault = new Rebalancer(
            address(asset),
            "Test Vault",
            "TV",
            providers,
            0.001 ether, // 0.1% withdrawal fee
            address(this),
            treasury
        );
        
        // Deploy fee collector
        feeCollector = new FeeCollector(treasury);
        
        // Grant admin role to this contract
        feeCollector.grantRole(ADMIN_ROLE, address(this));
        
        // Setup vault
        asset.mint(address(this), DEPOSIT_AMOUNT);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.setupVault(DEPOSIT_AMOUNT);
    }
    
    function testRegisterVault() public {
        vm.expectEmit(true, false, false, true);
        emit VaultRegistered(address(vault), COLLECTION_INTERVAL);
        
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        FeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(address(vault));
        
        assertTrue(vaultInfo.isRegistered);
        assertEq(vaultInfo.lastCollectionTime, block.timestamp);
        assertEq(vaultInfo.collectionInterval, COLLECTION_INTERVAL);
        assertEq(vaultInfo.totalFeesCollected, 0);
    }
    
    function testRegisterVaultRevertsIfVaultIsZero() public {
        vm.expectRevert(FeeCollector.FeeCollector__InvalidVault.selector);
        feeCollector.registerVault(address(0), COLLECTION_INTERVAL);
    }
    
    function testRegisterVaultRevertsIfIntervalTooSmall() public {
        vm.expectRevert(FeeCollector.FeeCollector__InvalidInterval.selector);
        feeCollector.registerVault(address(vault), 12 hours); // Less than 1 day
    }
    
    function testRegisterVaultRevertsIfIntervalTooLarge() public {
        vm.expectRevert(FeeCollector.FeeCollector__InvalidInterval.selector);
        feeCollector.registerVault(address(vault), 31 days); // More than 30 days
    }
    
    function testUnregisterVault() public {
        // First register the vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Then unregister it
        feeCollector.unregisterVault(address(vault));
        
        FeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(address(vault));
        assertFalse(vaultInfo.isRegistered);
    }
    
    function testUnregisterVaultRevertsIfNotRegistered() public {
        vm.expectRevert(FeeCollector.FeeCollector__InvalidVault.selector);
        feeCollector.unregisterVault(address(vault));
    }
    
    function testCollectFees() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Simulate fees accumulated in vault
        asset.mint(address(vault), FEE_AMOUNT);
        
        // Approve fee collector to spend vault's tokens
        vm.prank(address(vault));
        asset.approve(address(feeCollector), FEE_AMOUNT);
        
        // Fast forward time to allow collection
        vm.warp(block.timestamp + COLLECTION_INTERVAL + 1);
        
        uint256 treasuryBalanceBefore = asset.balanceOf(treasury);
        
        vm.expectEmit(true, true, false, true);
        emit FeesCollected(address(vault), address(asset), FEE_AMOUNT);
        
        feeCollector.collectFees(address(vault));
        
        uint256 treasuryBalanceAfter = asset.balanceOf(treasury);
        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, FEE_AMOUNT);
        
        // Check vault info updated
        FeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(address(vault));
        assertEq(vaultInfo.totalFeesCollected, FEE_AMOUNT);
    }
    
    function testCollectFeesRevertsIfNotEnoughTimePassed() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Try to collect immediately
        vm.expectRevert(FeeCollector.FeeCollector__NotEnoughTimePassed.selector);
        feeCollector.collectFees(address(vault));
    }
    
    function testCollectFeesRevertsIfNoFees() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Fast forward time
        vm.warp(block.timestamp + COLLECTION_INTERVAL + 1);
        
        // Try to collect when no fees available
        vm.expectRevert(FeeCollector.FeeCollector__NoFeesToCollect.selector);
        feeCollector.collectFees(address(vault));
    }
    
    function testCollectAllFees() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Simulate fees
        asset.mint(address(vault), FEE_AMOUNT);
        
        // Approve fee collector to spend vault's tokens
        vm.prank(address(vault));
        asset.approve(address(feeCollector), FEE_AMOUNT);
        
        // Fast forward time
        vm.warp(block.timestamp + COLLECTION_INTERVAL + 1);
        
        uint256 treasuryBalanceBefore = asset.balanceOf(treasury);
        
        feeCollector.collectAllFees();
        
        uint256 treasuryBalanceAfter = asset.balanceOf(treasury);
        assertEq(treasuryBalanceAfter - treasuryBalanceBefore, FEE_AMOUNT);
    }
    
    function testSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.expectEmit(true, false, false, true);
        emit TreasuryUpdated(newTreasury);
        
        feeCollector.setTreasury(newTreasury);
        
        assertEq(feeCollector.treasury(), newTreasury);
    }
    
    function testSetTreasuryRevertsIfZero() public {
        vm.expectRevert(FeeCollector.FeeCollector__InvalidVault.selector);
        feeCollector.setTreasury(address(0));
    }
    
    function testUpdateCollectionInterval() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        uint256 newInterval = 14 days;
        feeCollector.updateCollectionInterval(address(vault), newInterval);
        
        FeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(address(vault));
        assertEq(vaultInfo.collectionInterval, newInterval);
    }
    
    function testIsVaultReadyForCollection() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Not ready initially
        assertFalse(feeCollector.isVaultReadyForCollection(address(vault)));
        
        // Fast forward time
        vm.warp(block.timestamp + COLLECTION_INTERVAL + 1);
        
        // Now ready
        assertTrue(feeCollector.isVaultReadyForCollection(address(vault)));
    }
    
    function testGetTimeUntilNextCollection() public {
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Should return full interval initially
        uint256 timeLeft = feeCollector.getTimeUntilNextCollection(address(vault));
        assertEq(timeLeft, COLLECTION_INTERVAL);
        
        // Fast forward half the interval
        vm.warp(block.timestamp + COLLECTION_INTERVAL / 2);
        
        timeLeft = feeCollector.getTimeUntilNextCollection(address(vault));
        assertEq(timeLeft, COLLECTION_INTERVAL / 2);
        
        // Fast forward past the interval
        vm.warp(block.timestamp + COLLECTION_INTERVAL);
        
        timeLeft = feeCollector.getTimeUntilNextCollection(address(vault));
        assertEq(timeLeft, 0);
    }
    
    function testGetRegisteredVaults() public {
        // Initially no vaults
        assertEq(feeCollector.getRegisteredVaultsCount(), 0);
        
        // Register vault
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        // Should have one vault
        assertEq(feeCollector.getRegisteredVaultsCount(), 1);
        
        address[] memory vaults = feeCollector.getRegisteredVaults();
        assertEq(vaults.length, 1);
        assertEq(vaults[0], address(vault));
    }
    
    function testOnlyAdminCanRegisterVault() public {
        vm.prank(alice);
        vm.expectRevert();
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
    }
    
    function testOnlyAdminCanUnregisterVault() public {
        feeCollector.registerVault(address(vault), COLLECTION_INTERVAL);
        
        vm.prank(alice);
        vm.expectRevert();
        feeCollector.unregisterVault(address(vault));
    }
    
    function testOnlyAdminCanSetTreasury() public {
        vm.prank(alice);
        vm.expectRevert();
        feeCollector.setTreasury(makeAddr("newTreasury"));
    }
}

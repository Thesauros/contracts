// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {WeeklyProfitFeeCollector} from "../../contracts/WeeklyProfitFeeCollector.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockVault} from "../mocks/MockVault.sol";

contract WeeklyProfitFeeCollectorTest is Test {
    WeeklyProfitFeeCollector public feeCollector;
    MockERC20 public mockAsset;
    MockVault public mockVault;
    
    address public treasury = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public admin = address(this); // Use test contract as admin
    
    uint256 public constant FEE_PERCENT = 2500; // 25%
    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDC
    
    function setUp() public {
        // Deploy mock asset
        mockAsset = new MockERC20("Mock USDC", "USDC", 6);
        
        // Deploy mock vault
        mockVault = new MockVault(address(mockAsset));
        
        // Deploy fee collector
        feeCollector = new WeeklyProfitFeeCollector(treasury);
        
        // Set up roles - admin role is already granted to deployer (this contract)
        
        // Mint initial tokens
        mockAsset.mint(user1, INITIAL_BALANCE);
        mockAsset.mint(user2, INITIAL_BALANCE);
        mockAsset.mint(address(mockVault), INITIAL_BALANCE * 10);
        
        // Give users some initial shares in the vault
        mockVault.mint(user1, INITIAL_BALANCE);
        mockVault.mint(user2, INITIAL_BALANCE);
        
        // Register vault
        feeCollector.registerVault(address(mockVault), FEE_PERCENT);
    }
    
    function testRegisterVault() public {
        address newVault = address(0x5);
        
        feeCollector.registerVault(newVault, FEE_PERCENT);
        
        WeeklyProfitFeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(newVault);
        
        assertTrue(vaultInfo.isRegistered);
        assertEq(vaultInfo.feePercent, FEE_PERCENT);
        assertEq(vaultInfo.collectionInterval, 7 days);
        assertEq(vaultInfo.totalFeesCollected, 0);
    }
    
    function testRegisterUser() public {
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        WeeklyProfitFeeCollector.UserInfo memory userInfo = feeCollector.getUserInfo(address(mockVault), user1);
        
        assertTrue(userInfo.isRegistered);
        assertEq(userInfo.lastCollectionTime, block.timestamp);
        assertEq(userInfo.lastShares, mockVault.balanceOf(user1));
        assertEq(userInfo.totalFeesCollected, 0);
        assertEq(userInfo.totalProfitsCollected, 0);
    }
    
    function testCalculateProfitFee() public {
        // Register user
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        // Simulate user having more shares (profit)
        uint256 initialShares = mockVault.balanceOf(user1);
        mockVault.mint(user1, initialShares / 4); // 25% profit
        
        (uint256 profit, uint256 fee) = feeCollector.calculateProfitFee(address(mockVault), user1);
        
        uint256 expectedProfit = mockVault.convertToAssets(initialShares / 4);
        uint256 expectedFee = (expectedProfit * FEE_PERCENT) / 10000;
        
        assertEq(profit, expectedProfit);
        assertEq(fee, expectedFee);
    }
    
    function testCollectUserProfitFees() public {
        // Register user
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        // Simulate user having more shares (profit)
        uint256 initialShares = mockVault.balanceOf(user1);
        mockVault.mint(user1, initialShares / 4); // 25% profit
        
        // Approve fee collector to spend user's shares
        vm.prank(user1);
        mockVault.approve(address(feeCollector), type(uint256).max);
        
        // Fast forward time to allow collection
        vm.warp(block.timestamp + 7 days + 1);
        
        uint256 treasuryBalanceBefore = mockAsset.balanceOf(treasury);
        
        // Collect fees
        feeCollector.collectUserProfitFees(address(mockVault), user1);
        
        uint256 treasuryBalanceAfter = mockAsset.balanceOf(treasury);
        
        // Check that fees were collected
        assertGt(treasuryBalanceAfter, treasuryBalanceBefore);
        
        // Check user info was updated
        WeeklyProfitFeeCollector.UserInfo memory userInfo = feeCollector.getUserInfo(address(mockVault), user1);
        
        assertTrue(userInfo.isRegistered);
        assertEq(userInfo.lastCollectionTime, block.timestamp);
        assertGt(userInfo.totalFeesCollected, 0);
        assertGt(userInfo.totalProfitsCollected, 0);
    }
    
    function testCannotCollectBeforeInterval() public {
        // Register user
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        // Try to collect immediately (should fail)
        vm.expectRevert(WeeklyProfitFeeCollector.WeeklyProfitFeeCollector__NotEnoughTimePassed.selector);
        feeCollector.collectUserProfitFees(address(mockVault), user1);
    }
    
    function testCannotCollectFromUnregisteredUser() public {
        // Try to collect from unregistered user (should fail)
        vm.expectRevert(WeeklyProfitFeeCollector.WeeklyProfitFeeCollector__UserNotRegistered.selector);
        feeCollector.collectUserProfitFees(address(mockVault), user1);
    }
    
    function testUpdateFeePercent() public {
        uint256 newFeePercent = 3000; // 30%
        
        feeCollector.updateFeePercent(address(mockVault), newFeePercent);
        
        WeeklyProfitFeeCollector.VaultInfo memory vaultInfo = feeCollector.getVaultInfo(address(mockVault));
        
        assertTrue(vaultInfo.isRegistered);
        assertEq(vaultInfo.feePercent, newFeePercent);
    }
    
    function testCannotExceedMaxFeePercent() public {
        uint256 maxFeePercent = 5001; // 50.01% (exceeds maximum)
        
        vm.expectRevert(WeeklyProfitFeeCollector.WeeklyProfitFeeCollector__InvalidFeePercent.selector);
        feeCollector.updateFeePercent(address(mockVault), maxFeePercent);
    }
    
    function testSetTreasury() public {
        address newTreasury = address(0x6);
        
        vm.prank(admin);
        feeCollector.setTreasury(newTreasury);
        
        assertEq(feeCollector.treasury(), newTreasury);
    }
    
    function testIsUserReadyForCollection() public {
        // Register user
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        // Should not be ready immediately
        assertFalse(feeCollector.isUserReadyForCollection(address(mockVault), user1));
        
        // Fast forward time
        vm.warp(block.timestamp + 7 days + 1);
        
        // Should be ready now
        assertTrue(feeCollector.isUserReadyForCollection(address(mockVault), user1));
    }
    
    function testGetTimeUntilNextCollection() public {
        // Register user
        vm.prank(user1);
        feeCollector.registerUser(address(mockVault), user1);
        
        uint256 timeUntilNext = feeCollector.getTimeUntilNextCollection(address(mockVault), user1);
        
        // Should be approximately 7 days
        assertApproxEqAbs(timeUntilNext, 7 days, 1);
        
        // Fast forward time
        vm.warp(block.timestamp + 3 days);
        
        timeUntilNext = feeCollector.getTimeUntilNextCollection(address(mockVault), user1);
        
        // Should be approximately 4 days
        assertApproxEqAbs(timeUntilNext, 4 days, 1);
    }
}

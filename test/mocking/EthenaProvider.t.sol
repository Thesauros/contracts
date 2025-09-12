// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {EthenaProvider} from "../../contracts/providers/EthenaProvider.sol";
import {IEthenaStaking} from "../../contracts/interfaces/ethena/IEthenaStaking.sol";
import {IUSDe} from "../../contracts/interfaces/ethena/IUSDe.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockEthenaStaking} from "./mocks/MockEthenaStaking.sol";
import {MockUSDe} from "./mocks/MockUSDe.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {IProviderManager} from "../../contracts/interfaces/IProviderManager.sol";

// Mock Vault for testing
contract MockVault {
    address public asset;
    
    constructor(address _asset) {
        asset = _asset;
    }
}

// Mock ProviderManager for testing
contract MockProviderManager is IProviderManager {
    mapping(string => mapping(address => address)) private yieldTokens;
    
    function setYieldToken(string memory identifier, address asset, address yieldToken) external {
        yieldTokens[identifier][asset] = yieldToken;
    }
    
    function getYieldToken(string memory identifier, address asset) external view override returns (address) {
        return yieldTokens[identifier][asset];
    }
    
    function getMarket(string memory, address, address) external pure override returns (address) {
        return address(0);
    }
    
    function setMarket(string memory, address, address, address) external pure override {}
}

contract EthenaProviderTest is Test {
    EthenaProvider public ethenaProvider;
    MockEthenaStaking public mockEthenaStaking;
    MockUSDe public mockUSDe;
    MockERC20 public mockCollateral;
    MockVault public mockVault;
    MockProviderManager public mockProviderManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant DEPOSIT_AMOUNT = 100e6;   // 100 USDT
    uint256 public constant TARGET_APY = 900;         // 9% in basis points (as returned by mock)

    function setUp() public {
        // Deploy mock contracts
        mockCollateral = new MockERC20("Mock USDT", "USDT", 6);
        mockUSDe = new MockUSDe("Mock USDe", "USDe", 6);
        mockEthenaStaking = new MockEthenaStaking(address(mockUSDe));
        mockVault = new MockVault(address(mockCollateral));
        mockProviderManager = new MockProviderManager();

        // Deploy EthenaProvider
        ethenaProvider = new EthenaProvider(address(mockProviderManager));

        // Setup ProviderManager mappings
        mockProviderManager.setYieldToken("Ethena_Provider", address(mockCollateral), address(mockEthenaStaking));

        // Setup initial balances
        mockCollateral.mint(alice, INITIAL_BALANCE);
        mockCollateral.mint(bob, INITIAL_BALANCE);
        mockUSDe.mint(address(ethenaProvider), INITIAL_BALANCE);

        // Label addresses for better debugging
        vm.label(address(ethenaProvider), "EthenaProvider");
        vm.label(address(mockEthenaStaking), "MockEthenaStaking");
        vm.label(address(mockUSDe), "MockUSDe");
        vm.label(address(mockCollateral), "MockCollateral");
        vm.label(address(mockVault), "MockVault");
        vm.label(address(mockProviderManager), "MockProviderManager");
    }

    function test_Constructor() public view {
        assertEq(ethenaProvider.getIdentifier(), "Ethena_Provider");
    }

    function test_Constructor_AddressZero() public {
        vm.expectRevert(EthenaProvider.EthenaProvider__AddressZero.selector);
        new EthenaProvider(address(0));
    }

    function test_GetDepositRate() public view {
        uint256 rate = ethenaProvider.getDepositRate(IVault(address(mockVault)));
        assertEq(rate, TARGET_APY);
    }

    function test_GetSource() public view{
        address source = ethenaProvider.getSource(address(mockCollateral), address(0), address(0));
        assertEq(source, address(mockEthenaStaking));
    }


    function test_GetTotalStaked() public view{
        uint256 totalStaked = ethenaProvider.getTotalStaked(IVault(address(mockVault)));
        assertEq(totalStaked, 0); // Initially 0
    }

    function test_GetPendingRewards() public view{
        uint256 pendingRewards = ethenaProvider.getPendingRewards(alice, IVault(address(mockVault)));
        assertEq(pendingRewards, 0); // Initially 0
    }

    function test_ClaimRewards() public {
        // This should not revert
        ethenaProvider.claimRewards(IVault(address(mockVault)));
    }

    function test_GetDepositBalance() public view{
        uint256 balance = ethenaProvider.getDepositBalance(alice, IVault(address(mockVault)));
        assertEq(balance, 0); // Initially 0
    }

    function test_InvalidAsset_Reverts() public {
        // Create a vault with wrong asset (not registered in ProviderManager)
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        // Test getDepositBalance with wrong asset
        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositBalance(alice, IVault(address(wrongVault)));

        // Test getDepositRate with wrong asset
        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositRate(IVault(address(wrongVault)));
    }

    function test_Deposit_Success() public {
        // Setup: Vault has tokens
        mockCollateral.mint(address(mockVault), DEPOSIT_AMOUNT);

        // Setup: EthenaProvider has USDe tokens for staking
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);

        // Setup: Vault approves EthenaProvider to spend its tokens
        vm.prank(address(mockVault));
        mockCollateral.approve(address(ethenaProvider), DEPOSIT_AMOUNT);

        // Execute deposit
        vm.prank(address(mockVault));
        bool success = ethenaProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertTrue(success);
        assertEq(mockEthenaStaking.getStakedBalance(address(ethenaProvider)), DEPOSIT_AMOUNT);
    }

    function test_Deposit_ZeroAmount_Reverts() public {
        vm.expectRevert(EthenaProvider.EthenaProvider__InvalidAmount.selector);
        ethenaProvider.deposit(0, IVault(address(mockVault)));
    }

    function test_Deposit_InsufficientVaultBalance_Reverts() public {
        // Setup: Vault has insufficient balance
        mockCollateral.mint(address(mockVault), DEPOSIT_AMOUNT - 1);

        vm.expectRevert("EthenaProvider: Insufficient vault balance");
        ethenaProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));
    }

    function test_Deposit_InvalidAsset_Reverts() public {
        // Create a vault with wrong asset
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.deposit(DEPOSIT_AMOUNT, IVault(address(wrongVault)));
    }

    function test_Withdraw_Success() public {
        // Setup: EthenaProvider has staked tokens
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Setup: EthenaProvider has collateral tokens to transfer back to vault
        mockCollateral.mint(address(ethenaProvider), DEPOSIT_AMOUNT);

        // Execute withdraw
        bool success = ethenaProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertTrue(success);
        assertEq(mockEthenaStaking.getStakedBalance(address(ethenaProvider)), 0);
        assertEq(mockCollateral.balanceOf(address(mockVault)), DEPOSIT_AMOUNT);
    }

    function test_Withdraw_ZeroAmount_Reverts() public {
        vm.expectRevert(EthenaProvider.EthenaProvider__InvalidAmount.selector);
        ethenaProvider.withdraw(0, IVault(address(mockVault)));
    }

    function test_Withdraw_InsufficientStakedBalance_Reverts() public {
        // Setup: EthenaProvider has no staked tokens
        vm.expectRevert("EthenaProvider: Insufficient staked balance");
        ethenaProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(mockVault)));
    }

    function test_Withdraw_InvalidAsset_Reverts() public {
        // Create a vault with wrong asset
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(wrongVault)));
    }

    function test_GetDepositBalance_AfterDeposit() public {
        // Setup: EthenaProvider has staked tokens
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Test getDepositBalance
        uint256 balance = ethenaProvider.getDepositBalance(address(ethenaProvider), IVault(address(mockVault)));
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function test_GetDepositRate_AfterStaking() public {
        // Setup: Some tokens are staked
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Test getDepositRate
        uint256 rate = ethenaProvider.getDepositRate(IVault(address(mockVault)));
        assertEq(rate, TARGET_APY);
    }

    function test_GetTotalStaked_AfterStaking() public {
        // Setup: Some tokens are staked
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Test getTotalStaked
        uint256 totalStaked = ethenaProvider.getTotalStaked(IVault(address(mockVault)));
        assertEq(totalStaked, DEPOSIT_AMOUNT);
    }

    function test_GetPendingRewards_AfterStaking() public {
        // Setup: Some tokens are staked
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Test getPendingRewards
        uint256 pendingRewards = ethenaProvider.getPendingRewards(address(ethenaProvider), IVault(address(mockVault)));
        assertGe(pendingRewards, 0); // Should be >= 0
    }

    function test_ClaimRewards_AfterStaking() public {
        // Setup: Some tokens are staked
        mockUSDe.mint(address(ethenaProvider), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockUSDe.approve(address(mockEthenaStaking), DEPOSIT_AMOUNT);
        vm.prank(address(ethenaProvider));
        mockEthenaStaking.stake(DEPOSIT_AMOUNT);

        // Test claimRewards (should not revert)
        ethenaProvider.claimRewards(IVault(address(mockVault)));
    }

    function test_InvalidAsset_AllMethods_Reverts() public {
        // Create a vault with wrong asset
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        // Test all methods with wrong asset
        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.deposit(DEPOSIT_AMOUNT, IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositBalance(alice, IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositRate(IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getTotalStaked(IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getPendingRewards(alice, IVault(address(wrongVault)));

        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.claimRewards(IVault(address(wrongVault)));
    }

    function test_InvalidAsset_ZeroAddress_Reverts() public {
        // Create a vault with zero address asset
        MockVault zeroVault = new MockVault(address(0));

        vm.expectRevert("EthenaProvider: Invalid asset");
        ethenaProvider.getDepositBalance(alice, IVault(address(zeroVault)));
    }
}


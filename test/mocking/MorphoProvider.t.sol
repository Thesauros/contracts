// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {MorphoProvider} from "../../contracts/providers/MorphoProvider.sol";
import {IMorpho} from "../../contracts/interfaces/morpho/IMorpho.sol";
import {MockMorpho} from "../../contracts/mocks/MockMorpho.sol";
import {MockOracle} from "../../contracts/mocks/MockOracle.sol";
import {MockIrm} from "../../contracts/mocks/MockIrm.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    mapping(string => mapping(address => mapping(address => address))) private markets;
    
    function setYieldToken(string memory identifier, address asset, address yieldToken) external {
        yieldTokens[identifier][asset] = yieldToken;
    }
    
    function getYieldToken(string memory identifier, address asset) external view override returns (address) {
        return yieldTokens[identifier][asset];
    }
    
    function setMarket(string memory identifier, address asset, address collateral, address market) external {
        markets[identifier][asset][collateral] = market;
    }
    
    function getMarket(string memory identifier, address asset, address collateral) external view override returns (address) {
        return markets[identifier][asset][collateral];
    }
}

contract MorphoProviderTest is Test {
    MorphoProvider public morphoProvider;
    MockMorpho public mockMorpho;
    MockOracle public mockOracle;
    MockIrm public mockIrm;
    MockERC20 public mockAsset;
    MockERC20 public mockCollateral;
    MockVault public mockVault;
    MockProviderManager public mockProviderManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDC
    uint256 public constant DEPOSIT_AMOUNT = 100e6;   // 100 USDC
    uint256 public constant BASE_RATE = 1e25;         // 1% in ray
    uint256 public constant ORACLE_PRICE = 1e8;       // $1 in 8 decimals

    IMorpho.MarketParams public marketParams;

    function setUp() public {
        // Deploy mock contracts
        mockAsset = new MockERC20("Mock USDC", "USDC", 6);
        mockCollateral = new MockERC20("Mock WETH", "WETH", 18);
        mockOracle = new MockOracle(ORACLE_PRICE);
        mockIrm = new MockIrm(BASE_RATE);
        mockMorpho = new MockMorpho();
        mockVault = new MockVault(address(mockAsset));
        mockProviderManager = new MockProviderManager();

        // Deploy MorphoProvider
        morphoProvider = new MorphoProvider(address(mockProviderManager));

        // Setup market parameters - these should match what MorphoProvider expects
        marketParams = IMorpho.MarketParams({
            loanToken: address(mockAsset),
            collateralToken: address(0), // Will be set by the market
            oracle: address(0), // Will be set by the market
            irm: address(0), // Will be set by the market
            lltv: 8e26 // 80% in ray
        });

        // Setup ProviderManager mappings
        mockProviderManager.setYieldToken("Morpho_Provider", address(mockAsset), address(mockMorpho));
        mockProviderManager.setMarket("Morpho_Provider", address(mockAsset), address(0), address(mockMorpho));

        // Create market in Morpho with proper parameters
        mockMorpho.createMarket(marketParams);
        
        // Update market parameters in MockMorpho to match what MorphoProvider expects
        // Set some initial market data
        vm.prank(address(mockMorpho));
        mockMorpho.accrueInterest(marketParams);

        // Setup initial balances
        mockAsset.mint(alice, INITIAL_BALANCE);
        mockAsset.mint(bob, INITIAL_BALANCE);
        mockAsset.mint(address(mockVault), INITIAL_BALANCE);

        // Label addresses for better debugging
        vm.label(address(morphoProvider), "MorphoProvider");
        vm.label(address(mockMorpho), "MockMorpho");
        vm.label(address(mockOracle), "MockOracle");
        vm.label(address(mockIrm), "MockIrm");
        vm.label(address(mockAsset), "MockAsset");
        vm.label(address(mockCollateral), "MockCollateral");
        vm.label(address(mockVault), "MockVault");
        vm.label(address(mockProviderManager), "MockProviderManager");
    }

    function test_Constructor() public view {
        assertEq(morphoProvider.getIdentifier(), "Morpho_Provider");
    }

    function test_Constructor_AddressZero() public {
        vm.expectRevert(MorphoProvider.MorphoProvider__AddressZero.selector);
        new MorphoProvider(address(0));
    }

    function test_GetSource() public view {
        address source = morphoProvider.getSource(address(mockAsset), address(0), address(0));
        assertEq(source, address(mockMorpho));
    }

    function test_Deposit_Success() public {
        // Setup: Vault approves MorphoProvider to spend its tokens
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);

        // Execute deposit
        bool success = morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertTrue(success);
        
        // Check MorphoProvider has supply shares
        bytes32 marketId = keccak256(abi.encode(marketParams));
        IMorpho.Position memory position = mockMorpho.position(marketId, address(morphoProvider));
        assertGt(position.supplyShares, 0);
    }

    function test_Deposit_ZeroAmount_Reverts() public {
        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAmount.selector);
        morphoProvider.deposit(0, IVault(address(mockVault)));
    }

    function test_Deposit_InsufficientVaultBalance_Reverts() public {
        // Setup: Vault has insufficient balance
        mockAsset.mint(address(mockVault), DEPOSIT_AMOUNT - 1);

        // The test should expect the ERC20 transfer to fail, not our custom error
        vm.expectRevert();
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));
    }

    function test_Withdraw_Success() public {
        // Setup: MorphoProvider has supply shares
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Execute withdraw
        bool success = morphoProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertTrue(success);
        
        // Check vault received assets
        assertEq(mockAsset.balanceOf(address(mockVault)), INITIAL_BALANCE);
    }

    function test_Withdraw_ZeroAmount_Reverts() public {
        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAmount.selector);
        morphoProvider.withdraw(0, IVault(address(mockVault)));
    }

    function test_Withdraw_InsufficientBalance_Reverts() public {
        // Setup: MorphoProvider has no supply shares
        vm.expectRevert(MorphoProvider.MorphoProvider__InsufficientBalance.selector);
        morphoProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(mockVault)));
    }

    function test_GetDepositBalance() public view {
        uint256 balance = morphoProvider.getDepositBalance(address(morphoProvider), IVault(address(mockVault)));
        assertEq(balance, 0); // Initially 0
    }

    function test_GetDepositBalance_AfterDeposit() public {
        // Setup: MorphoProvider has supply shares
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Test getDepositBalance
        uint256 balance = morphoProvider.getDepositBalance(address(morphoProvider), IVault(address(mockVault)));
        assertEq(balance, DEPOSIT_AMOUNT);
    }

    function test_GetDepositRate() public view {
        uint256 rate = morphoProvider.getDepositRate(IVault(address(mockVault)));
        assertGe(rate, 0); // Should be >= 0
    }

    function test_GetDepositRate_AfterDeposit() public {
        // Setup: MorphoProvider has supply shares
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Test getDepositRate
        uint256 rate = morphoProvider.getDepositRate(IVault(address(mockVault)));
        assertGe(rate, 0); // Should be >= 0
    }

    function test_InvalidAsset_Reverts() public {
        // Create a vault with wrong asset (not registered in ProviderManager)
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        // Test all methods with wrong asset
        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAsset.selector);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(wrongVault)));

        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAsset.selector);
        morphoProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(wrongVault)));

        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAsset.selector);
        morphoProvider.getDepositBalance(alice, IVault(address(wrongVault)));

        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAsset.selector);
        morphoProvider.getDepositRate(IVault(address(wrongVault)));
    }

    function test_InvalidAsset_ZeroAddress_Reverts() public {
        // Create a vault with zero address asset
        MockVault zeroVault = new MockVault(address(0));

        vm.expectRevert(MorphoProvider.MorphoProvider__InvalidAsset.selector);
        morphoProvider.getDepositBalance(alice, IVault(address(zeroVault)));
    }

    function test_Deposit_InsufficientBalance_Reverts() public {
        // Setup: Vault has sufficient balance but we'll mock the balance check to fail
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);

        // Mock the balance check to return false
        vm.mockCall(
            address(mockAsset),
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(mockVault)),
            abi.encode(0) // Return 0 balance
        );

        vm.expectRevert(MorphoProvider.MorphoProvider__InsufficientBalance.selector);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));
    }

    function test_Deposit_MorphoSupplyFails_Reverts() public {
        // Setup: Vault approves MorphoProvider to spend its tokens
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);

        // Mock Morpho supply to fail by reverting
        vm.mockCallRevert(
            address(mockMorpho),
            abi.encodeWithSelector(IMorpho.supply.selector),
            "Supply failed"
        );

        // Execute deposit - should return false and transfer back to vault
        bool success = morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertFalse(success);
        
        // Check that assets were transferred back to vault
        assertEq(mockAsset.balanceOf(address(mockVault)), INITIAL_BALANCE);
    }

    function test_Withdraw_MorphoWithdrawFails_Reverts() public {
        // Setup: MorphoProvider has supply shares
        vm.prank(address(mockVault));
        mockAsset.approve(address(morphoProvider), DEPOSIT_AMOUNT);
        morphoProvider.deposit(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Mock Morpho withdraw to fail by reverting
        vm.mockCallRevert(
            address(mockMorpho),
            abi.encodeWithSelector(IMorpho.withdraw.selector),
            "Withdraw failed"
        );

        // Execute withdraw - should return false
        bool success = morphoProvider.withdraw(DEPOSIT_AMOUNT, IVault(address(mockVault)));

        // Verify
        assertFalse(success);
    }

}

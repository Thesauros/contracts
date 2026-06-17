// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {AccessManager} from "../../contracts/access/AccessManager.sol";
import {VaultManager} from "../../contracts/VaultManager.sol";
import {MockProviderA, MockProviderB} from "../../contracts/mocks/MockProvider.sol";
import {MockingUtilities} from "../utils/MockingUtilities.sol";

contract VaultManagerTests is MockingUtilities {
    function setUp() public {
        initializeVault(vault, MIN_AMOUNT, initializer);

        executeDeposit(vault, DEPOSIT_AMOUNT, alice);
        executeDeposit(vault, DEPOSIT_AMOUNT, bob);
    }

    // =========================================
    // rebalanceVault
    // =========================================

    function testRebalanceVaultRevertsIfCallerIsNotExecutor() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;

        vm.expectRevert(
            AccessManager.AccessManager__CallerIsNotExecutor.selector
        );
        vm.prank(alice);
        vaultManager.rebalanceVault(
            vault,
            assets,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultRevertsIfVaultIsNotApproved() public {
        vaultManager.setVaultApproval(address(vault), false);

        vm.expectRevert(VaultManager.VaultManager__VaultNotApproved.selector);
        vaultManager.rebalanceVault(
            vault,
            DEPOSIT_AMOUNT,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultRevertsIfSourceAndDestinationMatch() public {
        vm.expectRevert(VaultManager.VaultManager__SameProvider.selector);
        vaultManager.rebalanceVault(
            vault,
            DEPOSIT_AMOUNT,
            mockProviderA,
            mockProviderA,
            0,
            false
        );
    }

    function testRebalanceVaultRevertsIfAssetAmountIsInvalid() public {
        vm.expectRevert(VaultManager.VaultManager__InvalidAssetAmount.selector);
        vaultManager.rebalanceVault(
            vault,
            0,
            mockProviderA,
            mockProviderB,
            0,
            false
        );

        uint256 invalidAssets = 2 * DEPOSIT_AMOUNT + MIN_AMOUNT + 1;

        vm.expectRevert(VaultManager.VaultManager__InvalidAssetAmount.selector);
        vaultManager.rebalanceVault(
            vault,
            invalidAssets,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultIfMaxAssetsAreUsed() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT + MIN_AMOUNT;

        vaultManager.rebalanceVault(
            vault,
            type(uint256).max,
            mockProviderA,
            mockProviderB,
            0,
            false
        );

        assertEq(mockProviderA.getDepositBalance(address(vault), vault), 0);
        assertEq(
            mockProviderB.getDepositBalance(address(vault), vault),
            assets
        );
    }

    function testRebalanceVault() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;

        vaultManager.rebalanceVault(
            vault,
            assets,
            mockProviderA,
            mockProviderB,
            0,
            false
        );

        assertEq(
            mockProviderA.getDepositBalance(address(vault), vault),
            MIN_AMOUNT
        );
        assertEq(
            mockProviderB.getDepositBalance(address(vault), vault),
            assets
        );
        assertEq(address(vault.activeProvider()), address(mockProviderA));
    }

    function testRebalanceVaultRevertsIfAmountIsBelowPolicyFloor() public {
        vaultManager.setRebalancePolicy(MIN_AMOUNT + 1, 10_000, 2_000, 0);

        vm.expectRevert(
            VaultManager.VaultManager__RebalanceAmountTooSmall.selector
        );
        vaultManager.rebalanceVault(
            vault,
            MIN_AMOUNT,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultRevertsIfVaultOutflowLimitIsExceeded() public {
        vaultManager.setRebalancePolicy(0, 5_000, 2_000, 0);

        vm.expectRevert(
            VaultManager.VaultManager__VaultOutflowLimitExceeded.selector
        );
        vaultManager.rebalanceVault(
            vault,
            type(uint256).max,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultRevertsIfFeeExceedsPolicyCap() public {
        vaultManager.setRebalancePolicy(0, 10_000, 100, 0);

        vm.expectRevert(VaultManager.VaultManager__RebalanceFeeTooHigh.selector);
        vaultManager.rebalanceVault(
            vault,
            DEPOSIT_AMOUNT,
            mockProviderA,
            mockProviderB,
            101 ether,
            false
        );
    }

    function testRebalanceVaultRevertsIfAprImprovementIsInsufficient() public {
        MockProviderA(address(mockProviderA)).setDepositRate(1e27);
        MockProviderB(address(mockProviderB)).setDepositRate(104e25);
        vaultManager.setRebalancePolicy(0, 10_000, 2_000, 5e25);

        vm.expectRevert(
            VaultManager.VaultManager__InsufficientAprImprovement.selector
        );
        vaultManager.rebalanceVault(
            vault,
            DEPOSIT_AMOUNT,
            mockProviderA,
            mockProviderB,
            0,
            false
        );
    }

    function testRebalanceVaultAllowsMoveWhenAprImprovementThresholdIsMet() public {
        MockProviderA(address(mockProviderA)).setDepositRate(1e27);
        MockProviderB(address(mockProviderB)).setDepositRate(108e25);
        vaultManager.setRebalancePolicy(0, 10_000, 2_000, 5e25);

        vaultManager.rebalanceVault(
            vault,
            DEPOSIT_AMOUNT,
            mockProviderA,
            mockProviderB,
            0,
            true
        );

        assertEq(address(vault.activeProvider()), address(mockProviderB));
    }
}

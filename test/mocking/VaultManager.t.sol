// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessManager} from "../../contracts/access/AccessManager.sol";
import {VaultManager} from "../../contracts/VaultManager.sol";
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
}

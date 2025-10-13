// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {IVault} from "./interfaces/IVault.sol";
import {AccessManager} from "./access/AccessManager.sol";

/**
 * @title VaultManager
 * @notice Centralized manager for vault rebalancing operations
 * @dev This contract provides a secure interface for executing rebalancing operations
 *      across different providers within vaults. It acts as an intermediary between
 *      external operators and vault contracts.
 * 
 * @custom:security Features:
 * - Only authorized executors can trigger rebalancing
 * - Validates asset amounts before execution
 * - Prevents invalid rebalancing operations
 * - Integrates with AccessManager for role-based permissions
 * 
 * @custom:rebalancing-process The rebalancing process:
 * 1. Validates the requested asset amount
 * 2. Checks that the source provider has sufficient assets
 * 3. Executes the rebalancing through the vault
 * 4. Optionally activates the destination provider
 * 
 * @custom:usage Example:
 * ```solidity
 * // Rebalance 1000 USDC from Aave to Morpho
 * vaultManager.rebalanceVault(
 *     usdcVault,
 *     1000e6, // 1000 USDC
 *     aaveProvider,
 *     morphoProvider,
 *     0, // No fee
 *     true // Activate Morpho as active provider
 * );
 * ```
 */
contract VaultManager is AccessManager {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error VaultManager__InvalidAssetAmount();

    /**
     * @notice Executes rebalancing of vault assets between providers
     * @param vault The vault contract to rebalance
     * @param assets The amount of assets to rebalance (use type(uint256).max for all available)
     * @param from The source provider currently holding the assets
     * @param to The destination provider that will receive the assets
     * @param fee The rebalancing fee to charge (in asset units)
     * @param activateToProvider Whether to set the destination provider as the new active provider
     * @return success Always returns true if the rebalancing succeeds
     * 
     * @dev The function performs several validations:
     * - Ensures the caller has executor permissions
     * - Validates that the asset amount is not zero and doesn't exceed available balance
     * - Checks that the source provider has sufficient assets
     * 
     * @dev The rebalancing process:
     * 1. Withdraws assets from the source provider
     * 2. Deposits assets into the destination provider
     * 3. Charges the specified fee to the treasury
     * 4. Optionally updates the active provider
     * 
     * @dev Use type(uint256).max for assets to rebalance all available funds
     * 
     * @custom:security Only executors can call this function
     * @custom:validation Reverts if asset amount is invalid or exceeds available balance
     */
    function rebalanceVault(
        IVault vault,
        uint256 assets,
        IProvider from,
        IProvider to,
        uint256 fee,
        bool activateToProvider
    ) external onlyExecutor returns (bool success) {
        uint256 assetsAtFrom = from.getDepositBalance(address(vault), vault);

        if (assets == type(uint256).max) {
            assets = assetsAtFrom;
        }
        if (assets == 0 || assets > assetsAtFrom) {
            revert VaultManager__InvalidAssetAmount();
        }

        vault.rebalance(assets, from, to, fee, activateToProvider);

        success = true;
    }
}

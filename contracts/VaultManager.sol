// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {IVault} from "./interfaces/IVault.sol";
import {AccessManager} from "./access/AccessManager.sol";

/**
 * @title VaultManager
 */
contract VaultManager is AccessManager {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error VaultManager__InvalidAssetAmount();

    /**
     * @notice Performs rebalancing of the vault by moving funds across providers.
     * @param vault The vault undergoing rebalancing.
     * @param assets The amount of assets to be rebalanced.
     * @param from The provider currently holding the assets.
     * @param to The provider receiving assets.
     * @param fee The fee amount charged for the rebalancing.
     * @param activateToProvider A flag indicating whether to mark the receiving provider as active.
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

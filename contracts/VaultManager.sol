// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    error VaultManager__InvalidCount();
    error VaultManager__ArrayMismatch();
    error VaultManager__InvalidAssetAmount();

    /**
     * @notice Performs rebalancing of the vault by moving funds across providers.
     * @param vault The vault undergoing rebalancing.
     * @param amounts An array of asset amounts to be rebalanced.
     * @param sources An array of providers holding the assets.
     * @param destinations An array of providers receiving the assets.
     * @param fees An array of fee amounts charged for each rebalancing.
     */
    function rebalanceVault(
        IVault vault,
        uint256[] memory amounts,
        IProvider[] memory sources,
        IProvider[] memory destinations,
        uint256[] memory fees
    ) external onlyExecutor returns (bool success) {
        uint256 count = amounts.length;
        if (count == 0) {
            revert VaultManager__InvalidCount();
        }
        if (
            count != sources.length ||
            count != destinations.length ||
            count != fees.length
        ) {
            revert VaultManager__ArrayMismatch();
        }

        for (uint256 i; i < count; i++) {
            uint256 assets = amounts[i];
            IProvider from = sources[i];
            IProvider to = destinations[i];
            uint256 fee = fees[i];

            uint256 assetsAtFrom = from.getDepositBalance(
                address(vault),
                vault
            );

            if (assets == type(uint256).max) {
                assets = assetsAtFrom;
            }
            if (assets == 0 || assets > assetsAtFrom) {
                revert VaultManager__InvalidAssetAmount();
            }

            vault.rebalance(assets, from, to, fee);
        }

        success = true;
    }
}

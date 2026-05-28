// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

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

    uint16 public constant BPS_DENOMINATOR = 10_000;

    struct RebalancePolicy {
        uint256 minRebalanceAmount;
        uint16 maxVaultOutflowBps;
        uint16 maxFeeBps;
        uint256 minAprImprovementRay;
    }

    /**
     * @dev Errors
     */
    error VaultManager__InvalidAssetAmount();
    error VaultManager__VaultNotApproved();
    error VaultManager__SameProvider();
    error VaultManager__RebalanceAmountTooSmall();
    error VaultManager__VaultOutflowLimitExceeded();
    error VaultManager__RebalanceFeeTooHigh();
    error VaultManager__InsufficientAprImprovement();
    error VaultManager__InvalidBps();

    mapping(address vault => bool approved) public approvedVaults;

    RebalancePolicy public rebalancePolicy;

    event VaultApprovalUpdated(address indexed vault, bool approved);
    event RebalancePolicyUpdated(
        uint256 minRebalanceAmount,
        uint16 maxVaultOutflowBps,
        uint16 maxFeeBps,
        uint256 minAprImprovementRay
    );

    constructor() {
        rebalancePolicy = RebalancePolicy({
            minRebalanceAmount: 0,
            maxVaultOutflowBps: BPS_DENOMINATOR,
            maxFeeBps: 2_000,
            minAprImprovementRay: 0
        });
    }

    function setVaultApproval(address vault, bool approved) external onlyAdmin {
        approvedVaults[vault] = approved;
        emit VaultApprovalUpdated(vault, approved);
    }

    function setRebalancePolicy(
        uint256 minRebalanceAmount,
        uint16 maxVaultOutflowBps,
        uint16 maxFeeBps,
        uint256 minAprImprovementRay
    ) external onlyAdmin {
        if (
            maxVaultOutflowBps == 0 ||
            maxVaultOutflowBps > BPS_DENOMINATOR ||
            maxFeeBps > BPS_DENOMINATOR
        ) {
            revert VaultManager__InvalidBps();
        }

        rebalancePolicy = RebalancePolicy({
            minRebalanceAmount: minRebalanceAmount,
            maxVaultOutflowBps: maxVaultOutflowBps,
            maxFeeBps: maxFeeBps,
            minAprImprovementRay: minAprImprovementRay
        });

        emit RebalancePolicyUpdated(
            minRebalanceAmount,
            maxVaultOutflowBps,
            maxFeeBps,
            minAprImprovementRay
        );
    }

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
        if (!approvedVaults[address(vault)]) {
            revert VaultManager__VaultNotApproved();
        }
        if (address(from) == address(to)) {
            revert VaultManager__SameProvider();
        }

        uint256 assetsAtFrom = from.getDepositBalance(address(vault), vault);
        RebalancePolicy memory policy = rebalancePolicy;

        if (assets == type(uint256).max) {
            assets = assetsAtFrom;
        }
        if (assets == 0 || assets > assetsAtFrom) {
            revert VaultManager__InvalidAssetAmount();
        }
        if (assets < policy.minRebalanceAmount) {
            revert VaultManager__RebalanceAmountTooSmall();
        }
        if (
            assets >
            (assetsAtFrom * uint256(policy.maxVaultOutflowBps)) /
                BPS_DENOMINATOR
        ) {
            revert VaultManager__VaultOutflowLimitExceeded();
        }
        if (fee > (assets * uint256(policy.maxFeeBps)) / BPS_DENOMINATOR) {
            revert VaultManager__RebalanceFeeTooHigh();
        }
        if (policy.minAprImprovementRay > 0) {
            uint256 fromRate = from.getDepositRate(vault);
            uint256 toRate = to.getDepositRate(vault);

            if (toRate < fromRate + policy.minAprImprovementRay) {
                revert VaultManager__InsufficientAprImprovement();
            }
        }

        vault.rebalance(assets, from, to, fee, activateToProvider);

        success = true;
    }
}

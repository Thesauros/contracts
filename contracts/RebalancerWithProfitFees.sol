// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {Vault} from "./base/Vault.sol";

/**
 * @title RebalancerWithProfitFees
 * @dev Rebalancer that charges fees on user profits during rebalancing
 */
contract RebalancerWithProfitFees is Vault {
    using SafeERC20 for IERC20Metadata;
    using Math for uint256;

    /**
     * @dev Errors
     */
    error RebalancerWithProfitFees__InvalidProvider();
    error RebalancerWithProfitFees__ExcessRebalanceFee();
    error RebalancerWithProfitFees__InvalidProfitFeePercent();

    /**
     * @dev Events
     */
    event ProfitFeeCharged(address indexed user, uint256 profit, uint256 fee);
    event ProfitFeePercentUpdated(uint256 newProfitFeePercent);

    /**
     * @dev State variables
     */
    uint256 public profitFeePercent; // Fee percentage on profits (25% = 2500 basis points)
    mapping(address => uint256) public userLastTotalAssets; // Track user's last total assets for profit calculation

    /**
     * @dev Constants
     */
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_PROFIT_FEE_PERCENT = 5000; // Maximum 50% fee on profits

    /**
     * @dev Initializes the RebalancerWithProfitFees contract with the specified parameters.
     * @param asset_ The address of the underlying asset managed by the vault.
     * @param name_ The name of the tokenized vault.
     * @param symbol_ The symbol of the tokenized vault.
     * @param providers_ An array of providers serving as a liquidity source for lending and/or yield.
     * @param withdrawFeePercent_ The fee percentage applied to withdrawals.
     * @param timelock_ The address of the timelock contract.
     * @param treasury_ The address of the treasury.
     * @param profitFeePercent_ The fee percentage applied to user profits (2500 = 25%).
     */
    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        IProvider[] memory providers_,
        uint256 withdrawFeePercent_,
        address timelock_,
        address treasury_,
        uint256 profitFeePercent_
    )
        Vault(
            asset_,
            name_,
            symbol_,
            providers_,
            withdrawFeePercent_,
            timelock_,
            treasury_
        )
    {
        _setProfitFeePercent(profitFeePercent_);
    }

    receive() external payable {}

    /**
     * @inheritdoc IVault
     */
    function rebalance(
        uint256 assets,
        IProvider from,
        IProvider to,
        uint256 fee,
        bool activateToProvider
    ) external onlyOperator returns (bool) {
        if (
            !_validateProvider(address(from)) || !_validateProvider(address(to))
        ) {
            revert RebalancerWithProfitFees__InvalidProvider();
        }

        _checkFee(fee, assets);

        // Calculate and collect profit fees before rebalancing
        _collectProfitFees();

        _delegateActionToProvider(assets, "withdraw", from);
        _delegateActionToProvider(assets - fee, "deposit", to);

        if (fee > 0) {
            address _treasury = treasury;

            _asset.safeTransfer(_treasury, fee);
            emit FeeCharged(_treasury, assets, fee);
        }

        if (activateToProvider) {
            _setActiveProvider(to);
        }

        emit RebalanceExecuted(
            assets,
            assets - fee,
            address(from),
            address(to)
        );
        return true;
    }

    /**
     * @notice Sets the profit fee percentage
     * @param _profitFeePercent The new profit fee percentage in basis points
     */
    function setProfitFeePercent(uint256 _profitFeePercent) external onlyAdmin {
        _setProfitFeePercent(_profitFeePercent);
    }

    /**
     * @notice Internal function to set the profit fee percentage
     * @param _profitFeePercent The new profit fee percentage in basis points
     */
    function _setProfitFeePercent(uint256 _profitFeePercent) internal {
        if (_profitFeePercent > MAX_PROFIT_FEE_PERCENT) {
            revert RebalancerWithProfitFees__InvalidProfitFeePercent();
        }
        profitFeePercent = _profitFeePercent;
        emit ProfitFeePercentUpdated(_profitFeePercent);
    }

    /**
     * @dev Collects profit fees from all users based on their profit since last rebalancing
     */
    function _collectProfitFees() internal {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            return;
        }

        uint256 currentTotalAssets = totalAssets();
        uint256 lastTotalAssets = userLastTotalAssets[address(0)]; // Use address(0) to store global last total assets

        if (currentTotalAssets <= lastTotalAssets) {
            // No profit to collect
            userLastTotalAssets[address(0)] = currentTotalAssets;
            return;
        }

        uint256 totalProfit = currentTotalAssets - lastTotalAssets;
        uint256 totalProfitFee = (totalProfit * profitFeePercent) / BASIS_POINTS;

        if (totalProfitFee == 0) {
            userLastTotalAssets[address(0)] = currentTotalAssets;
            return;
        }

        // Calculate how many shares to burn to collect the profit fee
        uint256 feeShares = _convertToShares(totalProfitFee, Math.Rounding.Ceil);
        
        // Burn shares from the vault's own balance (this reduces the value of all shares proportionally)
        _burn(address(this), feeShares);
        
        // Withdraw the profit fee from the active provider
        _delegateActionToProvider(totalProfitFee, "withdraw", activeProvider);
        
        // Transfer the profit fee to treasury
        address _treasury = treasury;
        _asset.safeTransfer(_treasury, totalProfitFee);

        // Update the last total assets
        userLastTotalAssets[address(0)] = currentTotalAssets;

        emit ProfitFeeCharged(address(0), totalProfit, totalProfitFee);
        emit FeeCharged(_treasury, totalProfit, totalProfitFee);
    }

    /**
     * @dev Ensures the rebalance fee is within a reasonable limit.
     * @param fee The fee amount to check.
     * @param amount The amount used to calculate the allowable fee.
     */
    function _checkFee(uint256 fee, uint256 amount) internal pure {
        uint256 reasonableFee = amount.mulDiv(
            MAX_REBALANCE_FEE_PERCENT,
            PRECISION_FACTOR
        );
        if (fee > reasonableFee) {
            revert RebalancerWithProfitFees__ExcessRebalanceFee();
        }
    }

    /**
     * @notice Manually trigger profit fee collection
     * @dev Can be called by anyone to collect profit fees
     */
    function collectProfitFees() external {
        _collectProfitFees();
    }

    /**
     * @notice Gets the current profit fee percentage
     * @return The profit fee percentage in basis points
     */
    function getProfitFeePercent() external view returns (uint256) {
        return profitFeePercent;
    }

    /**
     * @notice Calculates the potential profit fee for the current period
     * @return profit The total profit since last collection
     * @return fee The fee amount that would be collected
     */
    function calculatePotentialProfitFee() external view returns (uint256 profit, uint256 fee) {
        uint256 currentTotalAssets = totalAssets();
        uint256 lastTotalAssets = userLastTotalAssets[address(0)];

        if (currentTotalAssets <= lastTotalAssets) {
            return (0, 0);
        }

        profit = currentTotalAssets - lastTotalAssets;
        fee = (profit * profitFeePercent) / BASIS_POINTS;

        return (profit, fee);
    }

    /**
     * @notice Gets the last total assets value
     * @return The last total assets value
     */
    function getLastTotalAssets() external view returns (uint256) {
        return userLastTotalAssets[address(0)];
    }
}

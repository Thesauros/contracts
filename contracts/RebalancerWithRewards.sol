// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IProvider} from "./interfaces/IProvider.sol";
import {Vault} from "./base/Vault.sol";

/**
 * @title RebalancerWithRewards
 */
contract RebalancerWithRewards is Vault {
    using SafeERC20 for IERC20Metadata;
    using Math for uint256;

    /**
     * @dev Errors
     */
    error RebalancerWithRewards__InvalidProvider();
    error RebalancerWithRewards__ExcessRebalanceFee();
    error RebalancerWithRewards__AddressZero();

    address public rewardsDistributor;

    /**
     * @dev Initializes the RebalancerWithRewards contract with the specified parameters.
     * @param asset_ The address of the underlying asset managed by the vault.
     * @param name_ The name of the tokenized vault.
     * @param symbol_ The symbol of the tokenized vault.
     * @param providers_ An array of providers serving as a liquidity source for lending and/or yield.
     * @param withdrawFeePercent_ The fee percentage applied to withdrawals.
     * @param rewardsDistributor_ The address responsible for distributing rewards.
     * @param timelock_ The address of the timelock contract.
     * @param treasury_ The address of the treasury.
     */
    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        IProvider[] memory providers_,
        uint256 withdrawFeePercent_,
        address rewardsDistributor_,
        address timelock_,
        address treasury_
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
        _setRewardsDistributor(rewardsDistributor_);
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
            revert RebalancerWithRewards__InvalidProvider();
        }

        _checkFee(fee, assets);

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
     * @notice Transfers rewards to the rewards distributor.
     * @param token The address of the rewards token.
     */
    function transferRewards(address token) external {
        uint256 amount = IERC20(token).balanceOf(address(this));
        address _rewardsDistributor = rewardsDistributor;
        IERC20Metadata(token).safeTransfer(_rewardsDistributor, amount);
        emit RewardsTransferred(_rewardsDistributor, amount);
    }

    /**
     * @notice Sets the rewards distributor for this rebalancer.
     * @param _rewardsDistributor The new rewards distributor address.
     */
    function setRewardsDistributor(
        address _rewardsDistributor
    ) external onlyAdmin {
        _setRewardsDistributor(_rewardsDistributor);
    }

    /**
     * @dev Internal function to set the rewards distributor for this rebalancer.
     * @param _rewardsDistributor The new rewards distributor address.
     */
    function _setRewardsDistributor(address _rewardsDistributor) internal {
        if (_rewardsDistributor == address(0)) {
            revert RebalancerWithRewards__AddressZero();
        }
        rewardsDistributor = _rewardsDistributor;
        emit DistributorUpdated(_rewardsDistributor);
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
            revert RebalancerWithRewards__ExcessRebalanceFee();
        }
    }
}

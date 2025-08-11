// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IFraxlendPair
 */
interface IFraxlendPair {
    function currentRateInfo()
        external
        view
        returns (
            uint64 lastBlock,
            uint64 feeToProtocolRate,
            uint64 lastTimestamp,
            uint64 ratePerSec,
            uint64 fullUtilizationRate
        );

    function balanceOf(address account) external view returns (uint256);

    function getPairAccounting()
        external
        view
        returns (
            uint128 _totalAssetAmount,
            uint128 _totalAssetShares,
            uint128 _totalBorrowAmount,
            uint128 _totalBorrowShares,
            uint256 _totalCollateral
        );

    function totalAssets() external view returns (uint256);

    /**
     * @notice Allows a user to Lend Assets by specifying the amount of Asset Tokens to lend
     */
    function deposit(
        uint256 _amount,
        address _receiver
    ) external returns (uint256 _sharesReceived);

    /**
     * @notice Allows a user to redeem their Asset Shares for a specified amount of Asset Tokens
     */
    function withdraw(
        uint256 _amount,
        address _receiver,
        address _owner
    ) external returns (uint256 _sharesToBurn);

    /**
     * @notice Converts a given number of shares to an asset amount
     */
    function toAssetAmount(
        uint256 _shares,
        bool _roundUp,
        bool _previewInterest
    ) external view returns (uint256 _amount);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IStrategyAdapter {
    function deployCapital(uint256 assets, bytes calldata params) external;

    function freeCapital(
        uint256 assets,
        bytes calldata params
    ) external returns (uint256 assetsFreed);

    function harvest(
        bytes calldata params
    ) external returns (int256 pnl, uint256 assetsOut);

    function totalValue() external view returns (uint256);

    function freeLiquidity() external view returns (uint256);

    function emergencyExit(
        bytes calldata params
    ) external returns (uint256 assetsOut);
}

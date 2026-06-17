// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @notice Minimal view surface used by the routing/keeper layer to enforce
///         policy decisions before sending cross-chain operations.
interface ICrossChainRoutingPolicy {
    /// @dev True when the system is in a visibility-degraded state due to stale reports.
    function hasStaleStrategyReports() external view returns (bool);

    /// @dev Maximum allocation size that preserves residual liquidity and buffer target.
    function maxAllocatableAssets() external view returns (uint256);
}


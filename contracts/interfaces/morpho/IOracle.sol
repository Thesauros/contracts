// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IOracle
/// @notice Interface for price oracles used by Morpho
interface IOracle {
    /// @notice Get the current price of the asset
    /// @return The current price in the oracle's base unit
    function price() external view returns (uint256);
}

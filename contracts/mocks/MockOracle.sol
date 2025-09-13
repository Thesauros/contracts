// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IOracle} from "../interfaces/morpho/IOracle.sol";

/// @title MockOracle
/// @notice Mock implementation of price oracle for testing
contract MockOracle is IOracle {
    /// @notice Current price (in 8 decimals, e.g., 1e8 for $1)
    uint256 public currentPrice;

    /// @notice Constructor
    /// @param initialPrice Initial price of the asset
    constructor(uint256 initialPrice) {
        currentPrice = initialPrice;
    }

    /// @notice Get the current price
    /// @return The current price
    function price() external view override returns (uint256) {
        return currentPrice;
    }

    /// @notice Set the current price (for testing)
    /// @param newPrice The new price
    function setPrice(uint256 newPrice) external {
        currentPrice = newPrice;
    }
}

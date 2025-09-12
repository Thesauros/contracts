// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMorpho} from "../interfaces/morpho/IMorpho.sol";
import {IIrm} from "../interfaces/morpho/IIrm.sol";

/// @title MockIrm
/// @notice Mock implementation of Interest Rate Model for testing
contract MockIrm is IIrm {
    /// @notice Base borrow rate (in ray, 1e27)
    uint256 public baseRate;

    /// @notice Constructor
    /// @param _baseRate Base borrow rate (in ray, 1e27)
    constructor(uint256 _baseRate) {
        baseRate = _baseRate;
    }

    /// @notice Get the current borrow rate
    /// @param market The market data
    /// @return The current borrow rate (in ray, 1e27)
    function borrowRate(
        IMorpho.MarketParams memory /* marketParams */,
        IMorpho.Market memory market
    ) external view override returns (uint256) {
        // Simple linear model based on utilization
        if (market.totalSupplyAssets == 0) return baseRate;
        
        uint256 utilization = (market.totalBorrowAssets * 1e27) / market.totalSupplyAssets;
        
        // Linear increase: baseRate + utilization * 0.1 (10% max rate)
        return baseRate + (utilization * 1e26) / 1e27; // 0.1 * 1e27 = 1e26
    }

    /// @notice Set the base rate (for testing)
    /// @param _baseRate New base rate
    function setBaseRate(uint256 _baseRate) external {
        baseRate = _baseRate;
    }
}

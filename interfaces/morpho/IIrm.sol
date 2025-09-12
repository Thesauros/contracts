// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMorpho} from "./IMorpho.sol";

/// @title IIrm
/// @notice Interface for Interest Rate Models used by Morpho
interface IIrm {
    /// @notice Get the current borrow rate for a market
    /// @param marketParams The market parameters
    /// @param market The market data
    /// @return The current borrow rate (in ray, 1e27)
    function borrowRate(
        IMorpho.MarketParams memory marketParams,
        IMorpho.Market memory market
    ) external view returns (uint256);
}

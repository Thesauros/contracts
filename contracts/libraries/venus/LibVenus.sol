// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {FixedPointMathLib} from "../FixedPointMathLib.sol";
import {IVToken} from "../../interfaces/venus/IVToken.sol";

/**
 * @title LibVenus
 * @notice Get up to date vToken data without mutating state.
 * @dev Inspired and modified from Transmissions11 (https://github.com/transmissions11/libcompound).
 */
library LibVenus {
    using FixedPointMathLib for uint256;

    /**
     * @dev Errors
     */
    error LibVenus__RateTooHigh();

    /**
     * @dev Returns the underlying balance of the user.
     */
    function viewUnderlyingBalanceOf(
        IVToken vToken,
        address user
    ) internal view returns (uint256) {
        return vToken.balanceOf(user).mulWadDown(viewExchangeRate(vToken));
    }

    /**
     * @dev Returns the current exchange rate for the specified vToken.
     */
    function viewExchangeRate(IVToken vToken) internal view returns (uint256) {
        /* Remember the initial block number or timestamp */
        uint256 currentSlotNumber = vToken.getBlockNumberOrTimestamp();
        uint256 accrualSlotNumberPrior = vToken.accrualBlockNumber();

        if (accrualSlotNumberPrior == currentSlotNumber) {
            return vToken.exchangeRateStored();
        }

        uint256 totalCash = vToken.getCash();
        uint256 borrowsPrior = vToken.totalBorrows();
        uint256 reservesPrior = vToken.totalReserves();

        uint256 borrowRateMantissa = vToken.borrowRatePerBlock();

        // Same as MAX_BORROW_RATE_MANTISSA in vToken.sol
        if (borrowRateMantissa > 0.00016667e16) {
            revert LibVenus__RateTooHigh();
        }

        uint256 interestAccumulated = (borrowRateMantissa *
            (currentSlotNumber - accrualSlotNumberPrior)).mulWadDown(
                borrowsPrior
            );

        uint256 totalReserves = vToken.reserveFactorMantissa().mulWadDown(
            interestAccumulated
        ) + reservesPrior;
        uint256 totalBorrows = interestAccumulated + borrowsPrior;
        uint256 totalSupply = vToken.totalSupply();

        // Reverts if totalSupply == 0
        return
            (totalCash + totalBorrows - totalReserves).divWadDown(totalSupply);
    }
}

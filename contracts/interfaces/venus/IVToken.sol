// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IVToken
 */
interface IVToken is IERC20 {
    function getCash() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function blocksOrSecondsPerYear() external view returns (uint256);

    function getBlockNumberOrTimestamp() external view returns (uint256);

    /**
     * @notice Sender supplies assets into the market and receives vTokens in exchange
     * @return error Always NO_ERROR for compatibility with Venus core tooling
     */
    function mint(uint256 mintAmount) external returns (uint256);

    /**
     * @notice Sender redeems vTokens in exchange for a specified amount of underlying asset
     * @return error Always NO_ERROR for compatibility with Venus core tooling
     */
    function redeemUnderlying(uint redeemAmount) external returns (uint256);

    /**
     * @notice Sender redeems vTokens in exchange for the underlying asset
     * @return error Always NO_ERROR for compatibility with Venus core tooling
     */
    function redeem(uint redeemTokens) external returns (uint256);
}

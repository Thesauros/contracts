// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title ComptrollerInterface
 */
interface ComptrollerInterface {
    function enterMarkets(
        address[] calldata vTokens
    ) external returns (uint[] memory);
}

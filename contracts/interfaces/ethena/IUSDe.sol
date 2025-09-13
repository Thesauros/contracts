// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IUSDe
 * @dev Interface for USDe token from Ethena Protocol
 */
interface IUSDe is IERC20 {
    /**
     * @notice Mint USDe tokens
     * @param to The address to mint to
     * @param amount The amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burn USDe tokens
     * @param from The address to burn from
     * @param amount The amount to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice Get the current exchange rate for minting USDe
     * @return The exchange rate
     */
    function getExchangeRate() external view returns (uint256);

    /**
     * @notice Check if an address is authorized to mint/burn
     * @param account The address to check
     * @return True if authorized
     */
    function isAuthorized(address account) external view returns (bool);
}

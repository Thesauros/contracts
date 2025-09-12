// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUSDe} from "../interfaces/ethena/IUSDe.sol";

/**
 * @title MockUSDe
 * @dev Mock implementation of USDe token for testing
 */
contract MockUSDe is ERC20, IUSDe {
    /**
     * @dev Errors
     */
    error MockUSDe__NotAuthorized();
    error MockUSDe__InvalidAmount();

    /**
     * @dev State variables
     */
    mapping(address => bool) public authorizedMinters;
    uint256 public constant EXCHANGE_RATE = 1e18; // 1:1 exchange rate

    /**
     * @dev Constructor
     */
    constructor() ERC20("Mock USDe", "mUSDe") {
        authorizedMinters[msg.sender] = true;
    }

    /**
     * @notice Mint USDe tokens
     * @param to The address to mint to
     * @param amount The amount to mint
     */
    function mint(address to, uint256 amount) external override {
        if (!authorizedMinters[msg.sender]) {
            revert MockUSDe__NotAuthorized();
        }
        if (amount == 0) {
            revert MockUSDe__InvalidAmount();
        }
        
        _mint(to, amount);
    }

    /**
     * @notice Burn USDe tokens
     * @param from The address to burn from
     * @param amount The amount to burn
     */
    function burn(address from, uint256 amount) external override {
        if (!authorizedMinters[msg.sender]) {
            revert MockUSDe__NotAuthorized();
        }
        if (amount == 0) {
            revert MockUSDe__InvalidAmount();
        }
        
        _burn(from, amount);
    }

    /**
     * @notice Get the current exchange rate for minting USDe
     * @return The exchange rate
     */
    function getExchangeRate() external pure override returns (uint256) {
        return EXCHANGE_RATE;
    }

    /**
     * @notice Check if an address is authorized to mint/burn
     * @param account The address to check
     * @return True if authorized
     */
    function isAuthorized(address account) external view override returns (bool) {
        return authorizedMinters[account];
    }

    /**
     * @notice Add authorized minter
     * @param account The address to authorize
     */
    function addAuthorizedMinter(address account) external {
        authorizedMinters[account] = true;
    }

    /**
     * @notice Remove authorized minter
     * @param account The address to remove authorization from
     */
    function removeAuthorizedMinter(address account) external {
        authorizedMinters[account] = false;
    }
}

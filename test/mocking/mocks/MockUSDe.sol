// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IUSDe} from "../../../contracts/interfaces/ethena/IUSDe.sol";

/**
 * @title MockUSDe
 * @dev Mock contract for testing USDe token functionality
 */
contract MockUSDe is IUSDe {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public authorized;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external override {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function burn(address from, uint256 amount) external override {
        require(balanceOf[from] >= amount, "Insufficient balance");
        totalSupply -= amount;
        balanceOf[from] -= amount;
    }

    function getExchangeRate() external pure override returns (uint256) {
        return 1e18; // 1:1 rate
    }

    function isAuthorized(address account) external view override returns (bool) {
        return authorized[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

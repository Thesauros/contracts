// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEthenaStaking} from "../../../contracts/interfaces/ethena/IEthenaStaking.sol";
import {IUSDe} from "../../../contracts/interfaces/ethena/IUSDe.sol";

/**
 * @title MockEthenaStaking
 * @dev Mock contract for testing Ethena staking functionality
 */
contract MockEthenaStaking is IEthenaStaking {
    IUSDe public immutable usdeToken;
    mapping(address => uint256) public stakedBalances;
    uint256 public totalStaked;
    mapping(address => uint256) public pendingRewards;

    constructor(address usdeToken_) {
        usdeToken = IUSDe(usdeToken_);
    }

    function stake(uint256 amount) external override {
        usdeToken.transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
    }

    function unstake(uint256 amount) external override {
        require(stakedBalances[msg.sender] >= amount, "Insufficient staked balance");
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        usdeToken.transfer(msg.sender, amount);
    }

    function getStakedBalance(address user) external view override returns (uint256) {
        return stakedBalances[user];
    }

    function getCurrentAPY() external pure override returns (uint256) {
        return 900; // 9% in basis points
    }

    function getTotalStaked() external view override returns (uint256) {
        return totalStaked;
    }

    function claimRewards() external override {
        // Mock implementation - just reset pending rewards
        pendingRewards[msg.sender] = 0;
    }

    function getPendingRewards(address user) external view override returns (uint256) {
        return pendingRewards[user];
    }
}

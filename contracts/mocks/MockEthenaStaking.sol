// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEthenaStaking} from "../interfaces/ethena/IEthenaStaking.sol";

/**
 * @title MockEthenaStaking
 * @dev Mock implementation of Ethena staking contract for testing
 */
contract MockEthenaStaking is IEthenaStaking {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error MockEthenaStaking__InvalidAmount();
    error MockEthenaStaking__InsufficientBalance();

    /**
     * @dev State variables
     */
    IERC20 public immutable usdeToken;
    uint256 public constant TARGET_APY = 900; // 9% in basis points
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastStakeTime;
    uint256 public totalStaked;

    /**
     * @dev Constructor
     * @param usdeToken_ Address of USDe token
     */
    constructor(address usdeToken_) {
        usdeToken = IERC20(usdeToken_);
    }

    /**
     * @notice Stake USDe tokens to earn rewards
     * @param amount The amount of USDe to stake
     */
    function stake(uint256 amount) external override {
        if (amount == 0) {
            revert MockEthenaStaking__InvalidAmount();
        }

        // Transfer USDe tokens from user to this contract
        usdeToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update staked balance
        stakedBalances[msg.sender] += amount;
        lastStakeTime[msg.sender] = block.timestamp;
        totalStaked += amount;
    }

    /**
     * @notice Unstake USDe tokens
     * @param amount The amount of USDe to unstake
     */
    function unstake(uint256 amount) external override {
        if (amount == 0) {
            revert MockEthenaStaking__InvalidAmount();
        }
        if (amount > stakedBalances[msg.sender]) {
            revert MockEthenaStaking__InsufficientBalance();
        }

        // Update staked balance
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        
        // Transfer USDe tokens back to user
        usdeToken.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Get the staked balance of a user
     * @param user The user address
     * @return The staked balance
     */
    function getStakedBalance(address user) external view override returns (uint256) {
        return stakedBalances[user];
    }

    /**
     * @notice Get the current APY for staking
     * @return The current APY in basis points (e.g., 900 for 9%)
     */
    function getCurrentAPY() external pure override returns (uint256) {
        return TARGET_APY;
    }

    /**
     * @notice Get the total staked amount
     * @return The total staked amount
     */
    function getTotalStaked() external view override returns (uint256) {
        return totalStaked;
    }

    /**
     * @notice Claim staking rewards
     */
    function claimRewards() external override {
        // Mock implementation - in real Ethena, this would claim actual rewards
        // For testing purposes, we just emit an event
        emit RewardsClaimed(msg.sender, 0);
    }

    /**
     * @notice Get pending rewards for a user
     * @param user The user address
     * @return The pending rewards
     */
    function getPendingRewards(address user) external view override returns (uint256) {
        // Mock implementation - calculate simple rewards based on time staked
        uint256 stakedAmount = stakedBalances[user];
        if (stakedAmount == 0) return 0;
        
        uint256 timeStaked = block.timestamp - lastStakeTime[user];
        uint256 rewards = (stakedAmount * TARGET_APY * timeStaked) / (10000 * SECONDS_PER_YEAR);
        
        return rewards;
    }

    /**
     * @dev Events
     */
    event RewardsClaimed(address indexed user, uint256 amount);
}

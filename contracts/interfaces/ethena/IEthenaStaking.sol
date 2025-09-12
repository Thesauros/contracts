// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IEthenaStaking
 * @dev Interface for Ethena Protocol staking contract
 */
interface IEthenaStaking {
    /**
     * @notice Stake USDe tokens to earn rewards
     * @param amount The amount of USDe to stake
     */
    function stake(uint256 amount) external;

    /**
     * @notice Unstake USDe tokens
     * @param amount The amount of USDe to unstake
     */
    function unstake(uint256 amount) external;

    /**
     * @notice Get the staked balance of a user
     * @param user The user address
     * @return The staked balance
     */
    function getStakedBalance(address user) external view returns (uint256);

    /**
     * @notice Get the current APY for staking
     * @return The current APY in basis points (e.g., 900 for 9%)
     */
    function getCurrentAPY() external view returns (uint256);

    /**
     * @notice Get the total staked amount
     * @return The total staked amount
     */
    function getTotalStaked() external view returns (uint256);

    /**
     * @notice Claim staking rewards
     */
    function claimRewards() external;

    /**
     * @notice Get pending rewards for a user
     * @param user The user address
     * @return The pending rewards
     */
    function getPendingRewards(address user) external view returns (uint256);

    /**
     * @notice Get the USDe token address
     * @return The USDe token address
     */
    function getUSDeToken() external view returns (address);
}

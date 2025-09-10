// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProvider} from "../interfaces/IProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IEthenaStaking} from "../interfaces/ethena/IEthenaStaking.sol";
import {IUSDe} from "../interfaces/ethena/IUSDe.sol";

/**
 * @title EthenaProvider
 * @dev Provider for Ethena Protocol with 9% APY
 */
contract EthenaProvider is IProvider {
    using SafeERC20 for IERC20;
    using SafeERC20 for IUSDe;

    /**
     * @dev Errors
     */
    error EthenaProvider__AddressZero();
    error EthenaProvider__InvalidAmount();
    error EthenaProvider__InsufficientBalance();

    /**
     * @dev State variables
     */
    IEthenaStaking public immutable ethenaStaking;
    IUSDe public immutable usdeToken;
    IERC20 public immutable collateralToken; 

    /**
     * @dev Constructor
     * @param ethenaStaking_ Address of Ethena staking contract
     * @param usdeToken_ Address of USDe token
     * @param collateralToken_ Address of collateral token (USDT/USDC)
     */
    constructor(
        address ethenaStaking_,
        address usdeToken_,
        address collateralToken_
    ) {
        if (ethenaStaking_ == address(0) || usdeToken_ == address(0) || collateralToken_ == address(0)) {
            revert EthenaProvider__AddressZero();
        }
        
        ethenaStaking = IEthenaStaking(ethenaStaking_);
        usdeToken = IUSDe(usdeToken_);
        collateralToken = IERC20(collateralToken_);
    }

    /**
     * @inheritdoc IProvider
     */
    function deposit(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        if (amount == 0) {
            revert EthenaProvider__InvalidAmount();
        }
        collateralToken.safeTransferFrom(address(vault), address(this), amount);
        uint256 usdeAmount = amount;
        IERC20(address(usdeToken)).approve(address(ethenaStaking), usdeAmount);
        ethenaStaking.stake(usdeAmount);

        success = true;
    }

    /**
     * @inheritdoc IProvider
     */
    function withdraw(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        if (amount == 0) {
            revert EthenaProvider__InvalidAmount();
        }

        ethenaStaking.unstake(amount);

        uint256 collateralAmount = amount;
        collateralToken.safeTransfer(address(vault), collateralAmount);

        success = true;
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositBalance(
        address user,
        IVault vault
    ) external view override returns (uint256 balance) {

        balance = ethenaStaking.getStakedBalance(user);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositRate(IVault vault) external view override returns (uint256 rate) {
        return ethenaStaking.getCurrentAPY();
    }

    /**
     * @inheritdoc IProvider
     */
    function getSource(
        address,
        address,
        address
    ) external view override returns (address source) {
        source = address(ethenaStaking);
    }

    /**
     * @inheritdoc IProvider
     */
    function getIdentifier() public pure override returns (string memory) {
        return "Ethena_Provider";
    }

    /**
     * @notice Claim rewards from Ethena staking
     * @dev This function can be called to claim accumulated rewards
     */
    function claimRewards() external {
        ethenaStaking.claimRewards();
    }

    /**
     * @notice Get pending rewards for a user
     * @param user The user address
     * @return The pending rewards amount
     */
    function getPendingRewards(address user) external view returns (uint256) {
        return ethenaStaking.getPendingRewards(user);
    }

    /**
     * @notice Get the current APY from Ethena
     * @return The current APY in basis points
     */
    function getCurrentAPY() external view returns (uint256) {
        return ethenaStaking.getCurrentAPY();
    }

    /**
     * @notice Get the total staked amount in Ethena
     * @return The total staked amount
     */
    function getTotalStaked() external view returns (uint256) {
        return ethenaStaking.getTotalStaked();
    }
}

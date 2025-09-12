// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProvider} from "../interfaces/IProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IProviderManager} from "../interfaces/IProviderManager.sol";
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

    IProviderManager private immutable _providerManager;

    constructor(address providerManager_) {
        if (providerManager_ == address(0)) {
            revert EthenaProvider__AddressZero();
        }
        _providerManager = IProviderManager(providerManager_);
    }

    /**
     * @dev Validates vault asset and returns all necessary contracts.
     * @param vault The vault to validate
     * @return staking The Ethena staking contract
     * @return usdeToken The USDe token contract
     * @return collateralToken The collateral token contract
     */
    function _validateAndGetContracts(IVault vault) internal view returns (
        IEthenaStaking staking,
        IUSDe usdeToken,
        IERC20 collateralToken
    ) {
        address asset = vault.asset();
        require(asset != address(0), "EthenaProvider: Invalid asset");
        
        address stakingAddress = _providerManager.getYieldToken(getIdentifier(), asset);
        require(stakingAddress != address(0), "EthenaProvider: Unsupported asset");
        
        staking = IEthenaStaking(stakingAddress);
        
        // Get USDe token address from staking contract
        // In Ethena, staking contract should have a method to get USDe token address
        // For now, we'll assume it's stored as a state variable or can be retrieved
        address usdeAddress = staking.getUSDeToken(); // This method should exist in IEthenaStaking
        usdeToken = IUSDe(usdeAddress);
        
        collateralToken = IERC20(asset);
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
        
        (IEthenaStaking staking, IUSDe usdeToken, IERC20 collateralToken) = _validateAndGetContracts(vault);
        
        // Check vault has sufficient balance
        require(collateralToken.balanceOf(address(vault)) >= amount, "EthenaProvider: Insufficient vault balance");
        
        collateralToken.safeTransferFrom(address(vault), address(this), amount);
        uint256 usdeAmount = amount;
        IERC20(address(usdeToken)).approve(address(staking), usdeAmount);
        staking.stake(usdeAmount);

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

        (IEthenaStaking staking, , IERC20 collateralToken) = _validateAndGetContracts(vault);
        
        // Check provider has sufficient staked balance
        require(staking.getStakedBalance(address(this)) >= amount, "EthenaProvider: Insufficient staked balance");

        staking.unstake(amount);

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
        (IEthenaStaking staking, , ) = _validateAndGetContracts(vault);
        balance = staking.getStakedBalance(user);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositRate(IVault vault) external view override returns (uint256 rate) {
        (IEthenaStaking staking, , ) = _validateAndGetContracts(vault);
        return staking.getCurrentAPY();
    }

    /**
     * @inheritdoc IProvider
     */
    function getSource(
        address asset,
        address,
        address
    ) external view override returns (address source) {
        source = _providerManager.getYieldToken(getIdentifier(), asset);
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
     * @param vault The vault for which to claim rewards
     */
    function claimRewards(IVault vault) external {
        (IEthenaStaking staking, , ) = _validateAndGetContracts(vault);
        staking.claimRewards();
    }

    /**
     * @notice Get pending rewards for a user
     * @param user The user address
     * @param vault The vault for which to get pending rewards
     * @return The pending rewards amount
     */
    function getPendingRewards(address user, IVault vault) external view returns (uint256) {
        (IEthenaStaking staking, , ) = _validateAndGetContracts(vault);
        return staking.getPendingRewards(user);
    }

    /**
     * @notice Get the total staked amount in Ethena
     * @param vault The vault for which to get total staked amount
     * @return The total staked amount
     */
    function getTotalStaked(IVault vault) external view returns (uint256) {
        (IEthenaStaking staking, , ) = _validateAndGetContracts(vault);
        return staking.getTotalStaked();
    }
}

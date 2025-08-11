// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "../interfaces/aaveV3/IPool.sol";
import {IPoolAddressesProvider} from "../interfaces/aaveV3/IPoolAddressesProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IProvider} from "../interfaces/IProvider.sol";

/**
 * @title AaveV3Provider
 */
contract AaveV3Provider is IProvider {
    /**
     * @inheritdoc IProvider
     */
    function deposit(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        IPool aave = _getPool();
        aave.supply(vault.asset(), amount, address(vault), 0);
        success = true;
    }

    /**
     * @inheritdoc IProvider
     */
    function withdraw(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        IPool aave = _getPool();
        aave.withdraw(vault.asset(), amount, address(vault));
        success = true;
    }

    /**
     * @dev Returns the Pool contract of Aave V3
     */
    function _getPool() internal view returns (IPool) {
        IPoolAddressesProvider addressesProvider = _getPoolAddressesProvider();
        return IPool(addressesProvider.getPool());
    }

    /**
     * @dev Returns the PoolAddressesProvider contract of Aave V3.
     */
    function _getPoolAddressesProvider()
        internal
        pure
        returns (IPoolAddressesProvider)
    {
        return
            IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositBalance(
        address user,
        IVault vault
    ) external view override returns (uint256 balance) {
        IPool aave = _getPool();
        IPool.ReserveData memory rdata = aave.getReserveData(vault.asset());
        balance = IERC20(rdata.aTokenAddress).balanceOf(user);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositRate(
        IVault vault
    ) external view override returns (uint256 rate) {
        IPool aave = _getPool();
        IPool.ReserveData memory rdata = aave.getReserveData(vault.asset());
        rate = rdata.currentLiquidityRate;
    }

    /**
     * @inheritdoc IProvider
     */
    function getSource(
        address,
        address,
        address
    ) external view override returns (address source) {
        source = address(_getPool());
    }

    /**
     * @inheritdoc IProvider
     */
    function getIdentifier() public pure override returns (string memory) {
        return "Aave_V3_Provider";
    }
}

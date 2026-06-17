// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IStrategyAdapter} from "../interfaces/crosschain/IStrategyAdapter.sol";
import {IPool} from "../interfaces/aaveV3/IPool.sol";
import {IPoolAddressesProvider} from "../interfaces/aaveV3/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3StrategyAdapter is IStrategyAdapter {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error AaveV3StrategyAdapter__InvalidProvider();
    error AaveV3StrategyAdapter__InvalidAsset();

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IERC20 public immutable ASSET;

    uint256 public deployedPrincipal;

    constructor(address addressesProvider_, address asset_) {
        if (addressesProvider_ == address(0)) {
            revert AaveV3StrategyAdapter__InvalidProvider();
        }
        if (asset_ == address(0)) {
            revert AaveV3StrategyAdapter__InvalidAsset();
        }

        ADDRESSES_PROVIDER = IPoolAddressesProvider(addressesProvider_);
        ASSET = IERC20(asset_);
    }

    function deployCapital(uint256 assets, bytes calldata) external {
        IPool pool = _getPool();

        ASSET.safeTransferFrom(msg.sender, address(this), assets);
        ASSET.forceApprove(address(pool), assets);
        pool.supply(address(ASSET), assets, address(this), 0);
        ASSET.forceApprove(address(pool), 0);

        deployedPrincipal += assets;
    }

    function freeCapital(
        uint256 assets,
        bytes calldata
    ) external returns (uint256 assetsFreed) {
        uint256 liquidity = freeLiquidity();
        assetsFreed = assets > liquidity ? liquidity : assets;
        if (assetsFreed == 0) {
            return 0;
        }

        IPool pool = _getPool();
        assetsFreed = pool.withdraw(address(ASSET), assetsFreed, address(this));
        ASSET.safeTransfer(msg.sender, assetsFreed);

        if (assetsFreed >= deployedPrincipal) {
            deployedPrincipal = 0;
        } else {
            deployedPrincipal -= assetsFreed;
        }
    }

    function harvest(
        bytes calldata
    ) external returns (int256 pnl, uint256 assetsOut) {
        uint256 currentValue = totalValue();
        if (currentValue <= deployedPrincipal) {
            pnl = -((deployedPrincipal - currentValue).toInt256());
            return (pnl, 0);
        }

        assetsOut = currentValue - deployedPrincipal;
        pnl = assetsOut.toInt256();
        uint256 liquidity = freeLiquidity();
        if (assetsOut > liquidity) {
            assetsOut = liquidity;
        }
        if (assetsOut == 0) {
            return (pnl, 0);
        }

        IPool pool = _getPool();
        assetsOut = pool.withdraw(address(ASSET), assetsOut, address(this));
        ASSET.safeTransfer(msg.sender, assetsOut);
    }

    function totalValue() public view returns (uint256) {
        return _aToken().balanceOf(address(this));
    }

    function freeLiquidity() public view returns (uint256) {
        return _aToken().balanceOf(address(this));
    }

    function emergencyExit(bytes calldata) external returns (uint256 assetsOut) {
        uint256 liquidity = freeLiquidity();
        if (liquidity == 0) {
            return 0;
        }

        IPool pool = _getPool();
        assetsOut = pool.withdraw(address(ASSET), liquidity, address(this));
        ASSET.safeTransfer(msg.sender, assetsOut);

        deployedPrincipal = 0;
    }

    function _getPool() internal view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER.getPool());
    }

    function _aToken() internal view returns (IERC20) {
        IPool.ReserveData memory rdata = _getPool().getReserveData(
            address(ASSET)
        );
        return IERC20(rdata.aTokenAddress);
    }
}

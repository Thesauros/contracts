// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IStrategyAdapter} from "../interfaces/crosschain/IStrategyAdapter.sol";
import {IMetaMorpho} from "../interfaces/morpho/IMetaMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MorphoStrategyAdapter is IStrategyAdapter {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error MorphoStrategyAdapter__InvalidMetaMorpho();
    error MorphoStrategyAdapter__InvalidAsset();

    IMetaMorpho public immutable META_MORPHO;
    IERC20 public immutable ASSET;

    uint256 public deployedPrincipal;

    constructor(address metaMorpho_) {
        if (metaMorpho_ == address(0)) {
            revert MorphoStrategyAdapter__InvalidMetaMorpho();
        }

        META_MORPHO = IMetaMorpho(metaMorpho_);

        address asset_ = IERC4626(metaMorpho_).asset();
        if (asset_ == address(0)) {
            revert MorphoStrategyAdapter__InvalidAsset();
        }

        ASSET = IERC20(asset_);
    }

    function deployCapital(uint256 assets, bytes calldata) external {
        ASSET.safeTransferFrom(msg.sender, address(this), assets);
        ASSET.forceApprove(address(META_MORPHO), assets);
        META_MORPHO.deposit(assets, address(this));
        ASSET.forceApprove(address(META_MORPHO), 0);

        deployedPrincipal += assets;
    }

    function freeCapital(
        uint256 assets,
        bytes calldata
    ) external returns (uint256 assetsFreed) {
        assetsFreed = assets > freeLiquidity() ? freeLiquidity() : assets;
        if (assetsFreed == 0) {
            return 0;
        }

        META_MORPHO.withdraw(assetsFreed, address(this), address(this));
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

        META_MORPHO.withdraw(assetsOut, address(this), address(this));
        ASSET.safeTransfer(msg.sender, assetsOut);
    }

    function totalValue() public view returns (uint256) {
        return META_MORPHO.convertToAssets(META_MORPHO.balanceOf(address(this)));
    }

    function freeLiquidity() public view returns (uint256) {
        return META_MORPHO.maxWithdraw(address(this));
    }

    function emergencyExit(bytes calldata) external returns (uint256 assetsOut) {
        assetsOut = freeLiquidity();
        if (assetsOut != 0) {
            META_MORPHO.withdraw(assetsOut, address(this), address(this));
            ASSET.safeTransfer(msg.sender, assetsOut);
        }

        deployedPrincipal = 0;
    }
}

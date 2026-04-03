// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IStrategyAdapter} from "../interfaces/crosschain/IStrategyAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockStrategyAdapter is IStrategyAdapter {
    using SafeERC20 for IERC20;

    IERC20 private immutable ASSET;

    uint256 public deployedBalance;
    int256 public harvestPnl;
    uint256 public harvestAssetsOut;
    uint256 public totalValueOverride;
    uint256 public freeLiquidityOverride;
    bool public hasReportingOverrides;

    constructor(address asset_) {
        ASSET = IERC20(asset_);
    }

    function setHarvestResult(int256 pnl, uint256 assetsOut) external {
        harvestPnl = pnl;
        harvestAssetsOut = assetsOut;
    }

    function setReportingState(
        uint256 totalValue_,
        uint256 freeLiquidity_
    ) external {
        totalValueOverride = totalValue_;
        freeLiquidityOverride = freeLiquidity_;
        hasReportingOverrides = true;
    }

    function clearReportingState() external {
        totalValueOverride = 0;
        freeLiquidityOverride = 0;
        hasReportingOverrides = false;
    }

    function deployCapital(uint256 assets, bytes calldata) external {
        ASSET.safeTransferFrom(msg.sender, address(this), assets);
        deployedBalance += assets;
    }

    function freeCapital(
        uint256 assets,
        bytes calldata
    ) external returns (uint256 assetsFreed) {
        assetsFreed = assets > deployedBalance ? deployedBalance : assets;
        deployedBalance -= assetsFreed;
        ASSET.safeTransfer(msg.sender, assetsFreed);
    }

    function harvest(
        bytes calldata
    ) external returns (int256 pnl, uint256 assetsOut) {
        pnl = harvestPnl;
        assetsOut = harvestAssetsOut > deployedBalance
            ? deployedBalance
            : harvestAssetsOut;

        if (assetsOut != 0) {
            deployedBalance -= assetsOut;
            ASSET.safeTransfer(msg.sender, assetsOut);
        }
    }

    function totalValue() external view returns (uint256) {
        if (hasReportingOverrides) {
            return totalValueOverride;
        }
        return deployedBalance;
    }

    function freeLiquidity() external view returns (uint256) {
        if (hasReportingOverrides) {
            return freeLiquidityOverride;
        }
        return deployedBalance;
    }

    function emergencyExit(bytes calldata) external returns (uint256 assetsOut) {
        assetsOut = deployedBalance;
        deployedBalance = 0;
        ASSET.safeTransfer(msg.sender, assetsOut);
    }
}

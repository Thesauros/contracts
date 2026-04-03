// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IReportSettler} from "./IReportSettler.sol";
import {IStrategyAllocator} from "./IStrategyAllocator.sol";
import {IStrategyRegistry} from "./IStrategyRegistry.sol";
import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";
import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface ICrossChainVault is IERC4626 {
    function homeIdle() external view returns (uint256);
    function targetLocalBufferAssets() external view returns (uint256);
    function minimumResidualLiquidity() external view returns (uint256);
    function fundedWithdrawalObligations() external view returns (uint256);
    function normalRedemptionSla() external view returns (uint64);
    function degradedRedemptionSla() external view returns (uint64);
    function delayedFundingPaused() external view returns (bool);

    function strategyRegistry() external view returns (IStrategyRegistry);

    function strategyAllocator() external view returns (IStrategyAllocator);

    function reportSettler() external view returns (IReportSettler);

    function withdrawalQueue() external view returns (IWithdrawalQueue);

    function availableHomeLiquidity() external view returns (uint256);
    function instantWithdrawalCapacity() external view returns (uint256);
    function currentRedemptionMode() external view returns (CrossChainTypes.RedemptionMode);
    function currentRedemptionSla() external view returns (uint64);

    function navBuckets()
        external
        view
        returns (CrossChainTypes.NavBuckets memory);

    function requestWithdrawal(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 requestId, uint256 assetsPreview);

    function startWithdrawalFunding(uint256 requestId) external;

    function fundWithdrawal(uint256 requestId) external;

    function claimWithdrawal(uint256 requestId) external returns (uint256 assets);

    function settleStrategyReport(uint32 strategyId) external;

    function setTargetLocalBufferAssets(uint256 assets) external;
    function setMinimumResidualLiquidity(uint256 assets) external;
    function setRedemptionSla(uint64 normalModeSla, uint64 degradedModeSla) external;
    function setDegradedRedemptionMode(bool enabled) external;
    function setDelayedFundingPaused(bool paused) external;
    function cancelWithdrawal(uint256 requestId) external;

    function syncOperationAccounting(bytes32 opId) external;

    function receiveRecallFunds(uint256 assets) external;
}

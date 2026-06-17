// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IReportSettler} from "./IReportSettler.sol";
import {IStrategyAllocator} from "./IStrategyAllocator.sol";
import {IStrategyRegistry} from "./IStrategyRegistry.sol";
import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface ICrossChainControlPlane {
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

    function availableHomeLiquidity() external view returns (uint256);

    function navBuckets()
        external
        view
        returns (CrossChainTypes.NavBuckets memory);

    function startWithdrawalFunding(uint256 requestId) external;

    function fundWithdrawal(uint256 requestId) external;

    function settleStrategyReport(uint32 strategyId) external;

    function setTargetLocalBufferAssets(uint256 assets) external;
    function setMinimumResidualLiquidity(uint256 assets) external;
    function setRedemptionSla(uint64 normalModeSla, uint64 degradedModeSla) external;
    function setDegradedRedemptionMode(bool enabled) external;
    function setDelayedFundingPaused(bool paused) external;

    function syncOperationAccounting(bytes32 opId) external;

    function dispatchRemoteOperation(
        bytes32 opId,
        address bridgeAdapter,
        bytes calldata params
    ) external payable returns (bytes32 messageId);

    function executeLocalAllocate(bytes32 opId, bytes calldata params) external;
    function executeLocalRecall(bytes32 opId, bytes calldata params) external;
    function executeLocalHarvest(bytes32 opId, bytes calldata params) external;
    function executeLocalEmergencyExit(bytes32 opId, bytes calldata params) external;

    function receiveRecallFunds(uint256 assets) external;
}

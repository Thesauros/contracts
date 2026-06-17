// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IRemoteStrategyAgent {
    event AssetConfigured(address indexed asset);
    event StrategyAdapterConfigured(address indexed strategyAdapter);
    event CommandReceived(bytes32 indexed opId, uint32 indexed strategyId);
    event CommandExecuted(bytes32 indexed opId, uint32 indexed strategyId);
    event CommandBridged(
        bytes32 indexed opId,
        bytes32 indexed messageId,
        uint32 indexed dstEid,
        uint256 assets
    );
    event StrategyReportPrepared(
        uint32 indexed strategyId,
        uint32 indexed chainId,
        uint64 reportTimestamp,
        bytes32 positionsHash,
        uint256 totalValue,
        uint256 freeLiquidity,
        uint256 totalDebt,
        int256 pnl
    );

    function asset() external view returns (address);
    function strategyAdapter() external view returns (address);
    function idleAssets() external view returns (uint256);
    function deployedAssets() external view returns (uint256);
    function lastPreparedReportTimestamp() external view returns (uint64);

    function setAsset(address asset_) external;
    function setStrategyAdapter(address strategyAdapter_) external;
    function receiveBridgeAsset(bytes calldata payload) external;
    function executeAllocate(bytes calldata command) external;
    function executeRecall(bytes calldata command) external;
    function bridgeAssetsHome(
        bytes calldata command,
        address bridgeAdapter,
        uint32 dstEid
    ) external returns (bytes32 messageId);
    function harvest(bytes calldata command) external;
    function emergencyExit(bytes calldata command) external;
    function previewStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external view returns (CrossChainTypes.StrategyReport memory report);
    function prepareStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external returns (CrossChainTypes.StrategyReport memory report);
}

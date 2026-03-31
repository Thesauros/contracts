// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IRemoteStrategyAgent {
    event CommandReceived(bytes32 indexed opId, uint32 indexed strategyId);
    event CommandExecuted(bytes32 indexed opId, uint32 indexed strategyId);

    function receiveBridgeAsset(bytes calldata payload) external;
    function executeAllocate(bytes calldata command) external;
    function executeRecall(bytes calldata command) external;
    function harvest(bytes calldata command) external;
    function emergencyExit(bytes calldata command) external;
}

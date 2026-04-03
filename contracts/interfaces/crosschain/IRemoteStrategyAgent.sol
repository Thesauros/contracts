// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IRemoteStrategyAgent {
    event AssetConfigured(address indexed asset);
    event StrategyAdapterConfigured(address indexed strategyAdapter);
    event CommandReceived(bytes32 indexed opId, uint32 indexed strategyId);
    event CommandExecuted(bytes32 indexed opId, uint32 indexed strategyId);

    function asset() external view returns (address);
    function strategyAdapter() external view returns (address);
    function idleAssets() external view returns (uint256);
    function deployedAssets() external view returns (uint256);

    function setAsset(address asset_) external;
    function setStrategyAdapter(address strategyAdapter_) external;
    function receiveBridgeAsset(bytes calldata payload) external;
    function executeAllocate(bytes calldata command) external;
    function executeRecall(bytes calldata command) external;
    function harvest(bytes calldata command) external;
    function emergencyExit(bytes calldata command) external;
}

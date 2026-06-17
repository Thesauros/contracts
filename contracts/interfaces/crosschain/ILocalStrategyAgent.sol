// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface ILocalStrategyAgent {
    function setAsset(address asset_) external;

    function setStrategyAdapter(address strategyAdapter_) external;

    function executeAllocate(bytes calldata command) external;

    function executeRecall(bytes calldata command) external returns (uint256 assetsFreed);

    function harvest(
        bytes calldata command
    ) external returns (int256 pnl, uint256 assetsOut);

    function emergencyExit(
        bytes calldata command
    ) external returns (uint256 assetsOut);

    function previewStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external view returns (CrossChainTypes.StrategyReport memory report);

    function prepareStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external returns (CrossChainTypes.StrategyReport memory report);
}

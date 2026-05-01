// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IStrategyRegistry {
    event StrategyConfigured(
        uint32 indexed strategyId,
        uint32 indexed chainId,
        address indexed agent,
        address asset
    );
    event StrategyStateUpdated(
        uint32 indexed strategyId,
        CrossChainTypes.StrategyHealth health,
        uint256 currentDebt,
        uint256 lastReportedValue
    );
    event StrategyAccountingUpdated(
        uint32 indexed strategyId,
        uint256 pendingBridgeIn,
        uint256 pendingBridgeOut,
        uint256 freeLiquidity,
        uint256 unrealizedLossBuffer,
        uint64 lastReportTimestamp
    );

    function upsertStrategy(
        CrossChainTypes.StrategyConfig calldata config
    ) external;

    function setStrategyState(
        uint32 strategyId,
        CrossChainTypes.StrategyState calldata state
    ) external;

    function getStrategyConfig(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyConfig memory);

    function getStrategyState(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyState memory);

    function strategyExists(uint32 strategyId) external view returns (bool);

    function strategyCount() external view returns (uint256);

    function strategyIdAt(uint256 index) external view returns (uint32);
}

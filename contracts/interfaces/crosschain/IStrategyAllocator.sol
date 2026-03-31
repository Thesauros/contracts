// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IStrategyAllocator {
    event OperationCreated(
        bytes32 indexed opId,
        uint32 indexed strategyId,
        CrossChainTypes.OperationType opType,
        uint256 assets
    );
    event OperationStatusUpdated(
        bytes32 indexed opId,
        CrossChainTypes.OperationStatus status
    );

    function createOperation(
        uint32 strategyId,
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut,
        uint64 deadline
    ) external returns (bytes32 opId);

    function setOperationStatus(
        bytes32 opId,
        CrossChainTypes.OperationStatus status
    ) external;

    function getOperation(
        bytes32 opId
    ) external view returns (CrossChainTypes.Operation memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IStrategyAllocator {
    event OperationCreated(
        bytes32 indexed opId,
        uint64 indexed nonce,
        uint32 indexed strategyId,
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut,
        uint64 deadline
    );
    event OperationStatusUpdated(
        bytes32 indexed opId,
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.OperationStatus status,
        uint64 statusTimestamp
    );
    event OperationDispatchRegistered(
        bytes32 indexed opId,
        uint32 indexed dstEid,
        address indexed remoteAgent,
        bytes32 bridgeMessageId,
        bytes32 payloadHash
    );

    function nextOperationNonce() external view returns (uint64);

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

    function registerBridgeDispatch(
        bytes32 opId,
        uint32 dstEid,
        address remoteAgent,
        bytes32 bridgeMessageId,
        bytes calldata encodedPayload
    ) external;

    function getOperation(
        bytes32 opId
    ) external view returns (CrossChainTypes.Operation memory);

    function getOperationDispatch(
        bytes32 opId
    ) external view returns (CrossChainTypes.OperationDispatch memory);

    function buildCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (CrossChainTypes.CommandPayloadV1 memory);

    function encodeCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (bytes memory);

    function hashCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (bytes32);
}

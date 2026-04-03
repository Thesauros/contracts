// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IStrategyAllocator} from "../interfaces/crosschain/IStrategyAllocator.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract StrategyAllocator is CrossChainAccessControl, IStrategyAllocator {
    error StrategyAllocator__UnknownOperation();
    error StrategyAllocator__InvalidDeadline();
    error StrategyAllocator__InvalidStatusTransition(
        CrossChainTypes.OperationStatus currentStatus,
        CrossChainTypes.OperationStatus nextStatus
    );
    error StrategyAllocator__InvalidDestinationEid();
    error StrategyAllocator__InvalidRemoteAgent();
    error StrategyAllocator__InvalidBridgeMessageId();
    error StrategyAllocator__DispatchAlreadyRegistered(bytes32 opId);
    error StrategyAllocator__InvalidPayloadVersion(uint8 version);
    error StrategyAllocator__PayloadOperationMismatch(bytes32 opId);

    uint64 public nextOperationNonce = 1;
    mapping(bytes32 opId => CrossChainTypes.Operation) private _operations;
    mapping(bytes32 opId => CrossChainTypes.OperationDispatch) private _dispatches;

    constructor(address admin) CrossChainAccessControl(admin) {}

    function createOperation(
        uint32 strategyId,
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut,
        uint64 deadline
    ) external onlyRole(ALLOCATOR_ROLE) returns (bytes32 opId) {
        if (deadline < block.timestamp) {
            revert StrategyAllocator__InvalidDeadline();
        }

        uint64 nonce = nextOperationNonce++;
        opId = keccak256(
            abi.encode(
                block.chainid,
                nonce,
                strategyId,
                opType,
                assets,
                minAssetsOut,
                deadline,
                block.timestamp
            )
        );

        _operations[opId] = CrossChainTypes.Operation({
            opId: opId,
            nonce: nonce,
            strategyId: strategyId,
            opType: opType,
            assets: assets,
            minAssetsOut: minAssetsOut,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            lastUpdatedAt: uint64(block.timestamp),
            status: CrossChainTypes.OperationStatus.Created
        });

        emit OperationCreated(
            opId,
            nonce,
            strategyId,
            opType,
            assets,
            minAssetsOut,
            deadline
        );
    }

    function setOperationStatus(
        bytes32 opId,
        CrossChainTypes.OperationStatus status
    ) external onlyRole(KEEPER_ROLE) {
        CrossChainTypes.Operation storage operation = _operations[opId];
        if (operation.opId == bytes32(0)) {
            revert StrategyAllocator__UnknownOperation();
        }
        if (!_isValidTransition(operation.status, status)) {
            revert StrategyAllocator__InvalidStatusTransition(
                operation.status,
                status
            );
        }

        CrossChainTypes.OperationStatus previousStatus = operation.status;
        operation.status = status;
        operation.lastUpdatedAt = uint64(block.timestamp);
        _recordDispatchTimestamp(opId, status, operation.lastUpdatedAt);

        emit OperationStatusUpdated(
            opId,
            previousStatus,
            status,
            operation.lastUpdatedAt
        );
    }

    function registerBridgeDispatch(
        bytes32 opId,
        uint32 dstEid,
        address remoteAgent,
        bytes32 bridgeMessageId,
        bytes calldata encodedPayload
    ) external onlyRole(BRIDGE_ROLE) {
        CrossChainTypes.Operation memory operation = _requireOperation(opId);
        if (dstEid == 0) {
            revert StrategyAllocator__InvalidDestinationEid();
        }
        if (remoteAgent == address(0)) {
            revert StrategyAllocator__InvalidRemoteAgent();
        }
        if (bridgeMessageId == bytes32(0)) {
            revert StrategyAllocator__InvalidBridgeMessageId();
        }
        if (_dispatches[opId].bridgeMessageId != bytes32(0)) {
            revert StrategyAllocator__DispatchAlreadyRegistered(opId);
        }

        CrossChainTypes.CommandPayloadV1 memory payload = abi.decode(
            encodedPayload,
            (CrossChainTypes.CommandPayloadV1)
        );
        _validatePayload(operation, payload);

        bytes32 payloadHash = keccak256(encodedPayload);
        _dispatches[opId] = CrossChainTypes.OperationDispatch({
            opId: opId,
            dstEid: dstEid,
            remoteAgent: remoteAgent,
            bridgeMessageId: bridgeMessageId,
            payloadHash: payloadHash,
            dispatchedAt: uint64(block.timestamp),
            receivedAt: 0,
            executedAt: 0,
            settledAt: 0
        });

        emit OperationDispatchRegistered(
            opId,
            dstEid,
            remoteAgent,
            bridgeMessageId,
            payloadHash
        );
    }

    function getOperation(
        bytes32 opId
    ) external view returns (CrossChainTypes.Operation memory) {
        return _requireOperation(opId);
    }

    function getOperationDispatch(
        bytes32 opId
    ) external view returns (CrossChainTypes.OperationDispatch memory) {
        _requireOperation(opId);
        return _dispatches[opId];
    }

    function buildCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (CrossChainTypes.CommandPayloadV1 memory) {
        CrossChainTypes.Operation memory operation = _requireOperation(opId);
        return _buildCommandPayload(operation, commandTimestamp, params);
    }

    function encodeCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (bytes memory) {
        CrossChainTypes.Operation memory operation = _requireOperation(opId);
        return abi.encode(_buildCommandPayload(operation, commandTimestamp, params));
    }

    function hashCommandPayload(
        bytes32 opId,
        uint64 commandTimestamp,
        bytes calldata params
    ) external view returns (bytes32) {
        CrossChainTypes.Operation memory operation = _requireOperation(opId);
        return
            keccak256(
                abi.encode(_buildCommandPayload(operation, commandTimestamp, params))
            );
    }

    function _isValidTransition(
        CrossChainTypes.OperationStatus currentStatus,
        CrossChainTypes.OperationStatus nextStatus
    ) private pure returns (bool) {
        if (currentStatus == CrossChainTypes.OperationStatus.Created) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Sent ||
                nextStatus == CrossChainTypes.OperationStatus.Cancelled ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        if (currentStatus == CrossChainTypes.OperationStatus.Sent) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Received ||
                nextStatus == CrossChainTypes.OperationStatus.Cancelled ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        if (currentStatus == CrossChainTypes.OperationStatus.Received) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Executed ||
                nextStatus == CrossChainTypes.OperationStatus.Cancelled ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        if (currentStatus == CrossChainTypes.OperationStatus.Executed) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Settled ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        return false;
    }

    function _requireOperation(
        bytes32 opId
    ) internal view returns (CrossChainTypes.Operation memory operation) {
        operation = _operations[opId];
        if (operation.opId == bytes32(0)) {
            revert StrategyAllocator__UnknownOperation();
        }
    }

    function _buildCommandPayload(
        CrossChainTypes.Operation memory operation,
        uint64 commandTimestamp,
        bytes calldata params
    ) internal view returns (CrossChainTypes.CommandPayloadV1 memory payload) {
        payload.version = 1;
        payload.opId = operation.opId;
        payload.strategyId = operation.strategyId;
        payload.sourceChainId = uint32(block.chainid);
        payload.commandType = _commandTypeFor(operation.opType);
        payload.assets = operation.assets;
        payload.minAssetsOut = operation.minAssetsOut;
        payload.deadline = operation.deadline;
        payload.commandTimestamp = commandTimestamp;
        payload.params = params;
    }

    function _commandTypeFor(
        CrossChainTypes.OperationType opType
    ) internal pure returns (CrossChainTypes.CommandType) {
        if (opType == CrossChainTypes.OperationType.Allocate) {
            return CrossChainTypes.CommandType.Allocate;
        }
        if (opType == CrossChainTypes.OperationType.Recall) {
            return CrossChainTypes.CommandType.Recall;
        }
        if (opType == CrossChainTypes.OperationType.Harvest) {
            return CrossChainTypes.CommandType.Harvest;
        }

        return CrossChainTypes.CommandType.EmergencyExit;
    }

    function _validatePayload(
        CrossChainTypes.Operation memory operation,
        CrossChainTypes.CommandPayloadV1 memory payload
    ) internal pure {
        if (payload.version != 1) {
            revert StrategyAllocator__InvalidPayloadVersion(payload.version);
        }
        if (
            payload.opId != operation.opId ||
            payload.strategyId != operation.strategyId ||
            payload.commandType != _commandTypeFor(operation.opType) ||
            payload.assets != operation.assets ||
            payload.minAssetsOut != operation.minAssetsOut ||
            payload.deadline != operation.deadline
        ) {
            revert StrategyAllocator__PayloadOperationMismatch(operation.opId);
        }
    }

    function _recordDispatchTimestamp(
        bytes32 opId,
        CrossChainTypes.OperationStatus status,
        uint64 timestamp
    ) internal {
        CrossChainTypes.OperationDispatch storage dispatch = _dispatches[opId];
        if (dispatch.opId == bytes32(0)) {
            return;
        }

        if (
            status == CrossChainTypes.OperationStatus.Sent &&
            dispatch.dispatchedAt == 0
        ) {
            dispatch.dispatchedAt = timestamp;
        } else if (
            status == CrossChainTypes.OperationStatus.Received &&
            dispatch.receivedAt == 0
        ) {
            dispatch.receivedAt = timestamp;
        } else if (
            status == CrossChainTypes.OperationStatus.Executed &&
            dispatch.executedAt == 0
        ) {
            dispatch.executedAt = timestamp;
        } else if (
            status == CrossChainTypes.OperationStatus.Settled &&
            dispatch.settledAt == 0
        ) {
            dispatch.settledAt = timestamp;
        }
    }
}

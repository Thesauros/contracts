// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IStrategyAllocator} from "../interfaces/crosschain/IStrategyAllocator.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract StrategyAllocator is CrossChainAccessControl, IStrategyAllocator {
    error StrategyAllocator__UnknownOperation();
    error StrategyAllocator__InvalidDeadline();
    error StrategyAllocator__InvalidStatusTransition();

    mapping(bytes32 opId => CrossChainTypes.Operation) private _operations;

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

        opId = keccak256(
            abi.encode(
                block.chainid,
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
            strategyId: strategyId,
            opType: opType,
            assets: assets,
            minAssetsOut: minAssetsOut,
            createdAt: uint64(block.timestamp),
            deadline: deadline,
            status: CrossChainTypes.OperationStatus.Created
        });

        emit OperationCreated(opId, strategyId, opType, assets);
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
            revert StrategyAllocator__InvalidStatusTransition();
        }

        operation.status = status;
        emit OperationStatusUpdated(opId, status);
    }

    function getOperation(
        bytes32 opId
    ) external view returns (CrossChainTypes.Operation memory) {
        CrossChainTypes.Operation memory operation = _operations[opId];
        if (operation.opId == bytes32(0)) {
            revert StrategyAllocator__UnknownOperation();
        }
        return operation;
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
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        if (currentStatus == CrossChainTypes.OperationStatus.Received) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Executed ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        if (currentStatus == CrossChainTypes.OperationStatus.Executed) {
            return
                nextStatus == CrossChainTypes.OperationStatus.Settled ||
                nextStatus == CrossChainTypes.OperationStatus.Failed;
        }
        return false;
    }
}

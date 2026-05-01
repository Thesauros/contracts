// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {ICrossChainRoutingPolicy} from "../interfaces/crosschain/ICrossChainRoutingPolicy.sol";
import {IStrategyAllocator} from "../interfaces/crosschain/IStrategyAllocator.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
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
    error StrategyAllocator__UnknownStrategy(uint32 strategyId);
    error StrategyAllocator__EmergencyExitOnly(uint32 strategyId);
    error StrategyAllocator__DepositsDisabled(uint32 strategyId);
    error StrategyAllocator__WithdrawalsDisabled(uint32 strategyId);
    error StrategyAllocator__StrategyNotActive(
        uint32 strategyId,
        CrossChainTypes.StrategyHealth health
    );
    error StrategyAllocator__StrategyReportStale(uint32 strategyId);
    error StrategyAllocator__DebtLimitExceeded(
        uint32 strategyId,
        uint256 requestedDebtAfter,
        uint256 debtLimit
    );
    error StrategyAllocator__MinAssetsOutTooLow(
        uint32 strategyId,
        uint256 minAssetsOut,
        uint256 requiredMinAssetsOut
    );
    error StrategyAllocator__DegradedModeNoAllocations();
    error StrategyAllocator__AllocationExceedsMaxAllocatable(
        uint256 assets,
        uint256 maxAllocatable
    );

    event RoutingPolicyUpdated(address indexed previous, address indexed current);

    uint64 public nextOperationNonce = 1;
    mapping(bytes32 opId => CrossChainTypes.Operation) private _operations;
    mapping(bytes32 opId => CrossChainTypes.OperationDispatch) private _dispatches;

    IStrategyRegistry private immutable STRATEGY_REGISTRY;
    ICrossChainRoutingPolicy public routingPolicy;

    constructor(
        address admin,
        IStrategyRegistry strategyRegistry_
    ) CrossChainAccessControl(admin) {
        if (address(strategyRegistry_) == address(0)) {
            revert StrategyAllocator__UnknownStrategy(0);
        }
        STRATEGY_REGISTRY = strategyRegistry_;
    }

    function strategyRegistry() public view returns (IStrategyRegistry) {
        return STRATEGY_REGISTRY;
    }

    function setRoutingPolicy(
        ICrossChainRoutingPolicy routingPolicy_
    ) external onlyRole(GOVERNANCE_ROLE) {
        address previous = address(routingPolicy);
        routingPolicy = routingPolicy_;
        emit RoutingPolicyUpdated(previous, address(routingPolicy_));
    }

    function createOperation(
        uint32 strategyId,
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut,
        uint64 deadline
    ) external onlyRole(ALLOCATOR_ROLE) returns (bytes32 opId) {
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline < block.timestamp) {
            revert StrategyAllocator__InvalidDeadline();
        }

        if (!STRATEGY_REGISTRY.strategyExists(strategyId)) {
            revert StrategyAllocator__UnknownStrategy(strategyId);
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(strategyId);
        CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
            .getStrategyState(strategyId);

        _validateOperationRequest(config, state, opType, assets, minAssetsOut);

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

        if (
            operation.opType == CrossChainTypes.OperationType.Allocate &&
            operation.status == CrossChainTypes.OperationStatus.Created &&
            status == CrossChainTypes.OperationStatus.Sent
        ) {
            ICrossChainRoutingPolicy policy = routingPolicy;
            if (address(policy) != address(0)) {
                if (policy.hasStaleStrategyReports()) {
                    revert StrategyAllocator__DegradedModeNoAllocations();
                }

                uint256 maxAllocatable = policy.maxAllocatableAssets();
                if (operation.assets > maxAllocatable) {
                    revert StrategyAllocator__AllocationExceedsMaxAllocatable(
                        operation.assets,
                        maxAllocatable
                    );
                }
            }
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

        // forge-lint: disable-next-line(asm-keccak256)
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
        bytes memory encodedPayload = abi.encode(
            _buildCommandPayload(operation, commandTimestamp, params)
        );
        // forge-lint: disable-next-line(asm-keccak256)
        return keccak256(encodedPayload);
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

    function _validateOperationRequest(
        CrossChainTypes.StrategyConfig memory config,
        CrossChainTypes.StrategyState memory state,
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut
    ) internal view {
        if (
            state.health == CrossChainTypes.StrategyHealth.Paused ||
            state.health == CrossChainTypes.StrategyHealth.EmergencyExitOnly ||
            state.health == CrossChainTypes.StrategyHealth.Deprecated
        ) {
            if (
                opType == CrossChainTypes.OperationType.Allocate ||
                opType == CrossChainTypes.OperationType.Harvest
            ) {
                revert StrategyAllocator__StrategyNotActive(
                    config.strategyId,
                    state.health
                );
            }
        }

        if (
            config.emergencyExitOnly ||
            state.health == CrossChainTypes.StrategyHealth.EmergencyExitOnly
        ) {
            if (
                opType == CrossChainTypes.OperationType.Allocate ||
                opType == CrossChainTypes.OperationType.Harvest
            ) {
                revert StrategyAllocator__EmergencyExitOnly(config.strategyId);
            }
        }

        if (opType == CrossChainTypes.OperationType.Allocate) {
            if (assets == 0) {
                // treat as no-op; disallow to avoid confusing accounting and policy.
                revert StrategyAllocator__DebtLimitExceeded(
                    config.strategyId,
                    0,
                    0
                );
            }
            if (!config.depositsEnabled) {
                revert StrategyAllocator__DepositsDisabled(config.strategyId);
            }

            // Only require freshness when the strategy already has exposure; this allows the
            // very first allocation into a new strategy.
            if (_strategyHasExposure(state) && _isStale(config, state)) {
                revert StrategyAllocator__StrategyReportStale(config.strategyId);
            }

            if (config.debtLimit != 0) {
                uint256 requestedAfter = state.currentDebt + state.pendingBridgeOut + assets;
                if (requestedAfter > uint256(config.debtLimit)) {
                    revert StrategyAllocator__DebtLimitExceeded(
                        config.strategyId,
                        requestedAfter,
                        uint256(config.debtLimit)
                    );
                }
            }
        } else if (opType == CrossChainTypes.OperationType.Recall) {
            if (assets == 0) {
                revert StrategyAllocator__DebtLimitExceeded(
                    config.strategyId,
                    0,
                    0
                );
            }
            if (!config.withdrawalsEnabled) {
                revert StrategyAllocator__WithdrawalsDisabled(config.strategyId);
            }
            if (assets > state.currentDebt) {
                revert StrategyAllocator__DebtLimitExceeded(
                    config.strategyId,
                    assets,
                    state.currentDebt
                );
            }
        } else if (opType == CrossChainTypes.OperationType.Harvest) {
            // no additional checks for v1 beyond state/emergency gating above.
        } else if (opType == CrossChainTypes.OperationType.EmergencyExit) {
            // always allowed; state/emergency gating above already restricts non-emergency ops.
        }

        if (assets != 0 && minAssetsOut != 0 && config.maxSlippageBps != 0) {
            uint256 requiredMinOut = (assets * (10_000 - uint256(config.maxSlippageBps))) / 10_000;
            if (minAssetsOut < requiredMinOut) {
                revert StrategyAllocator__MinAssetsOutTooLow(
                    config.strategyId,
                    minAssetsOut,
                    requiredMinOut
                );
            }
        }
    }

    function _strategyHasExposure(
        CrossChainTypes.StrategyState memory state
    ) internal pure returns (bool) {
        return
            state.currentDebt != 0 ||
            state.pendingBridgeIn != 0 ||
            state.pendingBridgeOut != 0 ||
            state.lastReportedValue != 0;
    }

    function _isStale(
        CrossChainTypes.StrategyConfig memory config,
        CrossChainTypes.StrategyState memory state
    ) internal view returns (bool) {
        if (config.maxReportDelay == 0) {
            return false;
        }
        if (state.lastReportTimestamp == 0) {
            return true;
        }
        // forge-lint: disable-next-line(block-timestamp)
        return block.timestamp > uint256(state.lastReportTimestamp) + config.maxReportDelay;
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract StrategyAllocatorTests is Test {
    StrategyAllocator internal allocator;

    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");

    uint32 internal constant STRATEGY_ID = 7;
    uint32 internal constant DST_EID = 30_101;

    function setUp() public {
        allocator = new StrategyAllocator(address(this));
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), bridge);
    }

    function testCreateOperationAssignsNonceAndCreatedState() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Allocate,
            100e6,
            99e6
        );

        CrossChainTypes.Operation memory operation = allocator.getOperation(opId);

        assertEq(operation.opId, opId);
        assertEq(operation.nonce, 1);
        assertEq(operation.strategyId, STRATEGY_ID);
        assertEq(
            uint8(operation.opType),
            uint8(CrossChainTypes.OperationType.Allocate)
        );
        assertEq(operation.assets, 100e6);
        assertEq(operation.minAssetsOut, 99e6);
        assertEq(operation.createdAt, block.timestamp);
        assertEq(operation.lastUpdatedAt, block.timestamp);
        assertEq(
            uint8(operation.status),
            uint8(CrossChainTypes.OperationStatus.Created)
        );
        assertEq(allocator.nextOperationNonce(), 2);
    }

    function testBuildCommandPayloadForRecallMatchesOperation() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Recall,
            50e6,
            49e6
        );

        bytes memory params = abi.encode(uint256(123));
        CrossChainTypes.CommandPayloadV1 memory payload = allocator
            .buildCommandPayload(opId, uint64(block.timestamp + 5 minutes), params);

        assertEq(payload.version, 1);
        assertEq(payload.opId, opId);
        assertEq(payload.strategyId, STRATEGY_ID);
        assertEq(payload.sourceChainId, uint32(block.chainid));
        assertEq(
            uint8(payload.commandType),
            uint8(CrossChainTypes.CommandType.Recall)
        );
        assertEq(payload.assets, 50e6);
        assertEq(payload.minAssetsOut, 49e6);
        assertEq(payload.deadline, uint64(block.timestamp + 1 days));
        assertEq(payload.commandTimestamp, uint64(block.timestamp + 5 minutes));
        assertEq(keccak256(payload.params), keccak256(params));
    }

    function testRegisterBridgeDispatchStoresCorrelationMetadata() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Allocate,
            100e6,
            99e6
        );

        bytes memory params = abi.encode("morpho");
        bytes memory encodedPayload = allocator.encodeCommandPayload(
            opId,
            uint64(block.timestamp + 1 minutes),
            params
        );
        bytes32 expectedPayloadHash = allocator.hashCommandPayload(
            opId,
            uint64(block.timestamp + 1 minutes),
            params
        );
        bytes32 bridgeMessageId = keccak256("lz-message");

        vm.prank(bridge);
        allocator.registerBridgeDispatch(
            opId,
            DST_EID,
            makeAddr("remoteAgent"),
            bridgeMessageId,
            encodedPayload
        );

        CrossChainTypes.OperationDispatch memory dispatch = allocator
            .getOperationDispatch(opId);

        assertEq(dispatch.opId, opId);
        assertEq(dispatch.dstEid, DST_EID);
        assertEq(dispatch.bridgeMessageId, bridgeMessageId);
        assertEq(dispatch.payloadHash, expectedPayloadHash);
        assertEq(dispatch.dispatchedAt, block.timestamp);
    }

    function testLifecycleSupportsHarvestOperation() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Harvest,
            0,
            0
        );
        _registerDispatch(opId);

        vm.warp(block.timestamp + 1 minutes);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);

        vm.warp(block.timestamp + 1 minutes);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Received);

        vm.warp(block.timestamp + 1 minutes);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Executed);

        vm.warp(block.timestamp + 1 minutes);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Settled);

        CrossChainTypes.Operation memory operation = allocator.getOperation(opId);
        CrossChainTypes.OperationDispatch memory dispatch = allocator
            .getOperationDispatch(opId);

        assertEq(
            uint8(operation.status),
            uint8(CrossChainTypes.OperationStatus.Settled)
        );
        assertEq(operation.lastUpdatedAt, block.timestamp);
        assertGt(dispatch.receivedAt, dispatch.dispatchedAt);
        assertGt(dispatch.executedAt, dispatch.receivedAt);
        assertGt(dispatch.settledAt, dispatch.executedAt);
    }

    function testLifecycleSupportsEmergencyExitOperation() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.EmergencyExit,
            0,
            0
        );

        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Received);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Executed);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Failed);

        CrossChainTypes.Operation memory operation = allocator.getOperation(opId);

        assertEq(
            uint8(operation.status),
            uint8(CrossChainTypes.OperationStatus.Failed)
        );
    }

    function testReceivedOperationCanBeCancelled() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Recall,
            25e6,
            24e6
        );

        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Received);
        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Cancelled);

        CrossChainTypes.Operation memory operation = allocator.getOperation(opId);
        assertEq(
            uint8(operation.status),
            uint8(CrossChainTypes.OperationStatus.Cancelled)
        );
    }

    function testRegisterBridgeDispatchRejectsPayloadMismatch() public {
        bytes32 opId = _createOperation(
            CrossChainTypes.OperationType.Allocate,
            100e6,
            99e6
        );
        bytes32 otherOpId = _createOperation(
            CrossChainTypes.OperationType.Allocate,
            100e6,
            99e6
        );

        bytes memory encodedPayload = allocator.encodeCommandPayload(
            otherOpId,
            uint64(block.timestamp + 1 minutes),
            bytes("")
        );

        vm.prank(bridge);
        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__PayloadOperationMismatch.selector,
                opId
            )
        );
        allocator.registerBridgeDispatch(
            opId,
            DST_EID,
            makeAddr("remoteAgent"),
            keccak256("msg"),
            encodedPayload
        );
    }

    function _createOperation(
        CrossChainTypes.OperationType opType,
        uint256 assets,
        uint256 minAssetsOut
    ) internal returns (bytes32 opId) {
        opId = allocator.createOperation(
            STRATEGY_ID,
            opType,
            assets,
            minAssetsOut,
            uint64(block.timestamp + 1 days)
        );
    }

    function _registerDispatch(bytes32 opId) internal {
        bytes memory encodedPayload = allocator.encodeCommandPayload(
            opId,
            uint64(block.timestamp + 1 minutes),
            bytes("")
        );

        vm.prank(bridge);
        allocator.registerBridgeDispatch(
            opId,
            DST_EID,
            makeAddr("remoteAgent"),
            keccak256(abi.encode(opId, "msg")),
            encodedPayload
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract DispatchRealAllocate is Script {
    struct Runtime {
        uint32 strategyId;
        uint256 assets;
        uint64 deadline;
        bytes params;
        uint256 feeBumpBps;
    }

    function run() external returns (bytes32 opId, bytes32 messageId) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        CrossChainVault vault = CrossChainVault(vm.envAddress("VAULT"));
        StrategyAllocator allocator = StrategyAllocator(
            vm.envAddress("ALLOCATOR_CONTRACT")
        );
        StrategyRegistry registry = StrategyRegistry(vm.envAddress("REGISTRY"));
        StargateBridgeAdapter bridge = StargateBridgeAdapter(
            vm.envAddress("BRIDGE_ADAPTER")
        );

        Runtime memory runtime = Runtime({
            strategyId: uint32(vm.envUint("STRATEGY_ID")),
            assets: vm.envUint("ALLOCATE_ASSETS"),
            deadline: uint64(block.timestamp + vm.envUint("DEADLINE_OFFSET")),
            params: bytes(vm.envString("COMMAND_PARAMS")),
            feeBumpBps: vm.envOr("FEE_BUMP_BPS", uint256(2000))
        });

        vm.startBroadcast(deployerKey);

        opId = allocator.createOperation(
            runtime.strategyId,
            CrossChainTypes.OperationType.Allocate,
            runtime.assets,
            0,
            runtime.deadline
        );

        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
        vault.syncOperationAccounting(opId);

        CrossChainTypes.StrategyConfig memory config = registry.getStrategyConfig(
            runtime.strategyId
        );
        bytes memory previewPayload = allocator.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            runtime.params
        );
        uint256 quotedFee = bridge.quoteTransportFee(
            config.chainId,
            vault.asset(),
            runtime.assets,
            previewPayload
        );
        uint256 dispatchValue = quotedFee +
            ((quotedFee * runtime.feeBumpBps) / 10_000);

        messageId = vault.dispatchRemoteOperation{value: dispatchValue}(
            opId,
            address(bridge),
            runtime.params
        );

        CrossChainTypes.OperationDispatch memory dispatchState = allocator
            .getOperationDispatch(opId);
        bytes memory payload = allocator.encodeCommandPayload(
            opId,
            dispatchState.dispatchedAt,
            runtime.params
        );

        vm.stopBroadcast();

        console2.log("chainId", block.chainid);
        console2.log("strategyId", runtime.strategyId);
        console2.log("assets", runtime.assets);
        console2.log("quotedFee", quotedFee);
        console2.log("dispatchValue", dispatchValue);
        console2.log("bridge", address(bridge));
        console2.log("opId");
        console2.logBytes32(opId);
        console2.log("messageId");
        console2.logBytes32(messageId);
        console2.log("dispatchedAt", dispatchState.dispatchedAt);
        console2.log("payloadHex");
        console2.logBytes(payload);
    }
}

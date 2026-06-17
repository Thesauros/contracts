// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";

contract WireStargateBridgeLive is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address bridgeAddr = vm.envAddress("BRIDGE_ADAPTER");
        address stargate = vm.envAddress("STARGATE");
        address endpointV2 = vm.envAddress("LAYERZERO_ENDPOINT_V2");
        uint32 peerEid = uint32(vm.envUint("PEER_EID"));
        bytes32 peer = vm.envBytes32("PEER");
        uint32 strategyId = uint32(vm.envUint("STRATEGY_ID"));
        address strategyReceiver = vm.envAddress("STRATEGY_RECEIVER");
        bytes memory sendOptions = vm.parseBytes(vm.envString("STARGATE_SEND_OPTIONS"));

        address vaultAddr = vm.envOr("VAULT", address(0));
        address allocatorAddr = vm.envOr("ALLOCATOR_CONTRACT", address(0));
        address remoteAgentAddr = vm.envOr("REMOTE_AGENT", address(0));

        vm.startBroadcast(deployerKey);

        StargateBridgeAdapter bridge = StargateBridgeAdapter(bridgeAddr);
        bridge.setTransport(stargate, endpointV2);
        bridge.setPeer(peerEid, peer);
        bridge.setSendOptions(peerEid, sendOptions);
        bridge.setStrategyReceiver(peerEid, strategyId, strategyReceiver);

        if (vaultAddr != address(0)) {
            CrossChainVault vault = CrossChainVault(vaultAddr);
            vault.grantRole(vault.BRIDGE_ROLE(), bridgeAddr);
            bridge.grantRole(bridge.BRIDGE_ROLE(), vaultAddr);
        }

        if (allocatorAddr != address(0)) {
            StrategyAllocator allocator = StrategyAllocator(allocatorAddr);
            allocator.grantRole(allocator.BRIDGE_ROLE(), bridgeAddr);
        }

        if (remoteAgentAddr != address(0)) {
            RemoteStrategyAgent remoteAgent = RemoteStrategyAgent(remoteAgentAddr);
            remoteAgent.grantRole(remoteAgent.BRIDGE_ROLE(), bridgeAddr);
            bridge.grantRole(bridge.BRIDGE_ROLE(), remoteAgentAddr);
        }

        vm.stopBroadcast();

        console2.log("chainId", block.chainid);
        console2.log("bridge", bridgeAddr);
        console2.log("stargate", stargate);
        console2.log("endpointV2", endpointV2);
        console2.log("peerEid", peerEid);
        console2.logBytes32(peer);
        console2.log("strategyId", strategyId);
        console2.log("strategyReceiver", strategyReceiver);
        console2.log("vault", vaultAddr);
        console2.log("allocator", allocatorAddr);
        console2.log("remoteAgent", remoteAgentAddr);
    }
}

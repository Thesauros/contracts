// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";

contract ConfigureStargateTransport is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address bridgeAddr = vm.envAddress("BRIDGE_ADAPTER");
        address stargate = vm.envAddress("STARGATE");
        address endpointV2 = vm.envAddress("LAYERZERO_ENDPOINT_V2");
        uint32 peerEid = uint32(vm.envUint("PEER_EID"));
        uint32 strategyId = uint32(vm.envUint("STRATEGY_ID"));
        address strategyReceiver = vm.envAddress("STRATEGY_RECEIVER");
        bytes memory sendOptions = vm.parseBytes(vm.envString("STARGATE_SEND_OPTIONS"));

        vm.startBroadcast(deployerKey);

        StargateBridgeAdapter bridge = StargateBridgeAdapter(bridgeAddr);
        bridge.setTransport(stargate, endpointV2);
        bridge.setSendOptions(peerEid, sendOptions);
        bridge.setStrategyReceiver(peerEid, strategyId, strategyReceiver);

        vm.stopBroadcast();

        console2.log("bridge", bridgeAddr);
        console2.log("stargate", stargate);
        console2.log("endpointV2", endpointV2);
        console2.log("peerEid", peerEid);
        console2.log("strategyId", strategyId);
        console2.log("strategyReceiver", strategyReceiver);
    }
}

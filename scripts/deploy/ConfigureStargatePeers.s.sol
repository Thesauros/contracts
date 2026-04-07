// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";

contract ConfigureStargatePeers is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address bridgeAddr = vm.envAddress("BRIDGE_ADAPTER");
        uint32 peerEid = uint32(vm.envUint("PEER_EID"));
        bytes32 peer = vm.envBytes32("PEER");

        vm.startBroadcast(deployerKey);
        StargateBridgeAdapter bridge = StargateBridgeAdapter(bridgeAddr);
        bridge.setPeer(peerEid, peer);
        vm.stopBroadcast();

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("bridge", bridgeAddr);
        console2.log("peerEid", peerEid);
        console2.logBytes32(peer);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainDeployConfig} from "./CrossChainDeployConfig.s.sol";

contract ConfigureStargatePeers is CrossChainDeployConfig {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address bridgeAddr = vm.envAddress("BRIDGE_ADAPTER");
        uint32 peerEid = uint32(vm.envOr("PEER_EID", uint256(0)));
        uint256 peerChainId = vm.envOr("PEER_CHAIN_ID", uint256(0));
        bytes32 peer = vm.envBytes32("PEER");

        if (peerEid == 0) {
            require(peerChainId != 0, "PEER_EID or PEER_CHAIN_ID required");
            peerEid = _stargateEidForChain(peerChainId);
        }

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

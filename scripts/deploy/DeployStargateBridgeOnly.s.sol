// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";

contract DeployStargateBridgeOnly is Script {
    function run() external returns (address bridgeAddr) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address governance = vm.envAddress("GOVERNANCE");

        vm.startBroadcast(deployerKey);
        StargateBridgeAdapter bridge = new StargateBridgeAdapter(governance);
        vm.stopBroadcast();

        bridgeAddr = address(bridge);

        console2.log("chainId", block.chainid);
        console2.log("governance", governance);
        console2.log("bridge", bridgeAddr);
        console2.log("bridge.localPeer(bytes32)");
        console2.logBytes32(bridge.localPeer());
    }
}

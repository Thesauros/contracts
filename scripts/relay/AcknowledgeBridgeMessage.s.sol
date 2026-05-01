// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";

/// @dev Source-side acknowledgement for the current bridge-control-plane adapters.
///      Run this against the source chain RPC after destination delivery succeeded.
///
///      Required env:
///      - PRIVATE_KEY
///      - SOURCE_BRIDGE_ADAPTER
///      - MESSAGE_ID
///      - PAYLOAD_HEX
contract AcknowledgeBridgeMessage is Script {
    function run() external {
        uint256 broadcasterKey = vm.envUint("PRIVATE_KEY");
        LayerZeroBridgeAdapter sourceBridge = LayerZeroBridgeAdapter(
            vm.envAddress("SOURCE_BRIDGE_ADAPTER")
        );
        bytes32 messageId = vm.envBytes32("MESSAGE_ID");
        bytes memory payload = vm.parseBytes(vm.envString("PAYLOAD_HEX"));

        vm.startBroadcast(broadcasterKey);
        sourceBridge.acknowledgeMessage(messageId, payload);
        vm.stopBroadcast();

        console2.log("source message acknowledged");
        console2.log("sourceBridge", address(sourceBridge));
        console2.log("messageId");
        console2.logBytes32(messageId);
    }
}

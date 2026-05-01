// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";

/// @dev Read-only helper to inspect a recorded bridge message on the source chain.
///
///      Required env:
///      - SOURCE_BRIDGE_ADAPTER
///      - MESSAGE_ID
contract InspectBridgeMessage is Script {
    function run() external view {
        LayerZeroBridgeAdapter sourceBridge = LayerZeroBridgeAdapter(
            vm.envAddress("SOURCE_BRIDGE_ADAPTER")
        );
        bytes32 messageId = vm.envBytes32("MESSAGE_ID");

        LayerZeroBridgeAdapter.BridgeMessage memory message = sourceBridge.getMessage(
            messageId
        );

        console2.log("messageId");
        console2.logBytes32(messageId);
        console2.log("sourceBridge", address(sourceBridge));
        console2.log("srcEid", message.srcEid);
        console2.log("dstEid", message.dstEid);
        console2.log("sender", message.sender);
        console2.log("receiver", message.receiver);
        console2.log("asset", message.asset);
        console2.log("amount", message.amount);
        console2.log("sentAt", message.sentAt);
        console2.log("timeoutAt", message.timeoutAt);
        console2.log("delivered", message.delivered);
        console2.log("acknowledged", message.acknowledged);
        console2.log("failed", message.failed);
        console2.log("srcPeer");
        console2.logBytes32(message.srcPeer);
        console2.log("dstPeer");
        console2.logBytes32(message.dstPeer);
        console2.log("payloadHash");
        console2.logBytes32(message.payloadHash);
    }
}

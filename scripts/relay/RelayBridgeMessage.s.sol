// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";

/// @dev Destination-side relay for the current bridge-control-plane adapters.
///      Run this against the destination chain RPC after an outbound message was
///      created on the source chain.
///
///      Required env:
///      - PRIVATE_KEY
///      - DEST_BRIDGE_ADAPTER
///      - MESSAGE_ID
///      - SOURCE_EID
///      - SOURCE_PEER
///      - ASSET
///      - AMOUNT
///      - DEST_RECEIVER
///      - PAYLOAD_HEX
///
///      Optional env:
///      - CALL_REMOTE_RECEIVE=true|false         (default false)
///      - REMOTE_AGENT                           (required if CALL_REMOTE_RECEIVE=true)
///      - CALL_HOME_RECEIVE_RECALL=true|false    (default false)
///      - HOME_VAULT                             (required if CALL_HOME_RECEIVE_RECALL=true)
contract RelayBridgeMessage is Script {
    function run() external {
        uint256 broadcasterKey = vm.envUint("PRIVATE_KEY");

        LayerZeroBridgeAdapter destBridge = LayerZeroBridgeAdapter(
            vm.envAddress("DEST_BRIDGE_ADAPTER")
        );

        bytes32 messageId = vm.envBytes32("MESSAGE_ID");
        uint32 sourceEid = uint32(vm.envUint("SOURCE_EID"));
        bytes32 sourcePeer = vm.envBytes32("SOURCE_PEER");
        address asset = vm.envAddress("ASSET");
        uint256 amount = vm.envUint("AMOUNT");
        address destReceiver = vm.envAddress("DEST_RECEIVER");
        bytes memory payload = vm.parseBytes(vm.envString("PAYLOAD_HEX"));

        bool callRemoteReceive = vm.envOr("CALL_REMOTE_RECEIVE", false);
        bool callHomeReceiveRecall = vm.envOr("CALL_HOME_RECEIVE_RECALL", false);

        vm.startBroadcast(broadcasterKey);

        destBridge.receiveAssetAndMessage(
            sourceEid,
            sourcePeer,
            messageId,
            asset,
            amount,
            destReceiver,
            payload
        );

        if (callRemoteReceive) {
            address remoteAgentAddr = vm.envAddress("REMOTE_AGENT");
            require(
                remoteAgentAddr == destReceiver,
                "REMOTE_AGENT must equal DEST_RECEIVER"
            );
            RemoteStrategyAgent(remoteAgentAddr).receiveBridgeAsset(payload);
        }

        if (callHomeReceiveRecall) {
            address homeVaultAddr = vm.envAddress("HOME_VAULT");
            require(
                homeVaultAddr == destReceiver,
                "HOME_VAULT must equal DEST_RECEIVER"
            );
            CrossChainVault(homeVaultAddr).receiveRecallFunds(amount);
        }

        vm.stopBroadcast();

        console2.log("destination message relayed");
        console2.log("messageId");
        console2.logBytes32(messageId);
        console2.log("destBridge", address(destBridge));
        console2.log("destReceiver", destReceiver);
        console2.log("asset", asset);
        console2.log("amount", amount);
        console2.log("callRemoteReceive", callRemoteReceive);
        console2.log("callHomeReceiveRecall", callHomeReceiveRecall);
    }
}

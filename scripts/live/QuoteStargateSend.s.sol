// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {
    IStargate,
    StargateBridgeAdapter
} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract QuoteStargateSend is Script {
    function run() external view {
        IStargate stargate = IStargate(vm.envAddress("STARGATE"));
        bytes32 peer = vm.envBytes32("PEER");
        address receiver = vm.envAddress("STRATEGY_RECEIVER");
        uint32 dstEid = uint32(vm.envUint("PEER_EID"));
        uint256 amount = vm.envUint("AMOUNT");
        bytes memory options = vm.parseBytes(vm.envString("STARGATE_SEND_OPTIONS"));
        bytes32 srcPeer = vm.envBytes32("SRC_PEER");
        bool disableCompose = vm.envOr("DISABLE_COMPOSE", false);
        bytes memory payload = _resolvePayload();
        bytes memory composeMsg;
        if (!disableCompose) {
            StargateBridgeAdapter.BridgeComposePayload
                memory composePayload = StargateBridgeAdapter.BridgeComposePayload({
                    srcPeer: srcPeer,
                    receiver: receiver,
                    payload: payload
                });
            composeMsg = abi.encode(composePayload);
        }

        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: peer,
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        (
            IStargate.OFTLimit memory limit,
            ,
            IStargate.OFTReceipt memory receipt
        ) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        console2.log("minAmountLD", limit.minAmountLD);
        console2.log("maxAmountLD", limit.maxAmountLD);
        console2.log("amountSentLD", receipt.amountSentLD);
        console2.log("amountReceivedLD", receipt.amountReceivedLD);

        IStargate.MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        console2.log("nativeFee", fee.nativeFee);
        console2.log("lzTokenFee", fee.lzTokenFee);
    }

    function _resolvePayload() internal view returns (bytes memory payload) {
        string memory payloadHex = vm.envOr("PAYLOAD_HEX", string(""));
        if (bytes(payloadHex).length != 0) {
            return vm.parseBytes(payloadHex);
        }

        payload = abi.encode(
            CrossChainTypes.CommandPayloadV1({
                version: 1,
                opId: vm.envBytes32("OP_ID"),
                strategyId: uint32(vm.envUint("STRATEGY_ID")),
                sourceChainId: uint32(vm.envUint("CHAIN_ID")),
                commandType: CrossChainTypes.CommandType(vm.envUint("COMMAND_TYPE")),
                assets: vm.envUint("AMOUNT"),
                minAssetsOut: vm.envOr("MIN_ASSETS_OUT", uint256(0)),
                deadline: uint64(vm.envUint("DEADLINE")),
                commandTimestamp: uint64(vm.envUint("COMMAND_TIMESTAMP")),
                params: bytes(vm.envString("COMMAND_PARAMS"))
            })
        );
    }
}

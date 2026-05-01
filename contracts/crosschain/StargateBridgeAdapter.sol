// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {LayerZeroBridgeAdapter} from "./LayerZeroBridgeAdapter.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";
import {IRemoteStrategyAgent} from "../interfaces/crosschain/IRemoteStrategyAgent.sol";
import {ICrossChainVault} from "../interfaces/crosschain/ICrossChainVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILayerZeroComposer {
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;
}

interface IStargate {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    function token() external view returns (address);
    function approvalRequired() external view returns (bool);
    function quoteSend(
        SendParam calldata sendParam,
        bool payInLzToken
    ) external view returns (MessagingFee memory);
    function send(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);
}

library StargateComposeCodec {
    uint256 private constant OFT_COMPOSE_NONCE_OFFSET = 8;
    uint256 private constant OFT_COMPOSE_SRC_EID_OFFSET = 12;
    uint256 private constant OFT_COMPOSE_AMOUNT_LD_OFFSET = 44;
    uint256 private constant OFT_COMPOSE_FROM_OFFSET = 76;

    function srcEid(bytes calldata message) internal pure returns (uint32) {
        return uint32(bytes4(message[OFT_COMPOSE_NONCE_OFFSET:OFT_COMPOSE_SRC_EID_OFFSET]));
    }

    function amountLD(bytes calldata message) internal pure returns (uint256) {
        return uint256(bytes32(message[OFT_COMPOSE_SRC_EID_OFFSET:OFT_COMPOSE_AMOUNT_LD_OFFSET]));
    }

    function composeFrom(bytes calldata message) internal pure returns (bytes32) {
        return bytes32(message[OFT_COMPOSE_AMOUNT_LD_OFFSET:OFT_COMPOSE_FROM_OFFSET]);
    }

    function composeMsg(bytes calldata message) internal pure returns (bytes calldata) {
        return message[OFT_COMPOSE_FROM_OFFSET:];
    }
}

/// @dev Stargate-backed adapter.
///      If Stargate transport is not configured, it falls back to the manual
///      LayerZeroBridgeAdapter control-plane behavior used by local tests.
contract StargateBridgeAdapter is LayerZeroBridgeAdapter, ILayerZeroComposer {
    using SafeERC20 for IERC20;
    using StargateComposeCodec for bytes;

    error StargateBridgeAdapter__TransportNotConfigured();
    error StargateBridgeAdapter__InvalidTransport(address stargate);
    error StargateBridgeAdapter__InvalidEndpointConfig(address endpoint);
    error StargateBridgeAdapter__UnsupportedAsset(address asset);
    error StargateBridgeAdapter__MissingRoute(uint32 dstEid, uint32 strategyId);
    error StargateBridgeAdapter__MissingExecutorOptions(uint32 dstEid);
    error StargateBridgeAdapter__InsufficientNativeFee(
        uint256 provided,
        uint256 required
    );
    error StargateBridgeAdapter__InvalidEndpoint(address caller);
    error StargateBridgeAdapter__InvalidComposer(address from);
    error StargateBridgeAdapter__InvalidComposeSender(bytes32 composeFrom);

    event StargateTransportConfigured(
        address indexed stargate,
        address indexed endpoint
    );
    event StargateRouteConfigured(
        uint32 indexed dstEid,
        uint32 indexed strategyId,
        address indexed receiver
    );
    event StargateSendOptionsConfigured(uint32 indexed dstEid, bytes options);

    struct BridgeComposePayload {
        bytes32 srcPeer;
        address receiver;
        bytes payload;
    }

    IStargate public stargate;
    address public endpointV2;
    mapping(uint32 dstEid => bytes sendOptions) public stargateSendOptions;
    mapping(uint32 dstEid => mapping(uint32 strategyId => address receiver))
        public strategyReceivers;

    constructor(address admin) LayerZeroBridgeAdapter(admin) {}

    function setTransport(
        address stargate_,
        address endpointV2_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (stargate_ == address(0)) {
            revert StargateBridgeAdapter__InvalidTransport(stargate_);
        }
        if (endpointV2_ == address(0)) {
            revert StargateBridgeAdapter__InvalidEndpointConfig(endpointV2_);
        }
        stargate = IStargate(stargate_);
        endpointV2 = endpointV2_;
        emit StargateTransportConfigured(stargate_, endpointV2_);
    }

    function setStrategyReceiver(
        uint32 dstEid,
        uint32 strategyId,
        address receiver
    ) external onlyRole(GOVERNANCE_ROLE) {
        strategyReceivers[dstEid][strategyId] = receiver;
        emit StargateRouteConfigured(dstEid, strategyId, receiver);
    }

    function setSendOptions(
        uint32 dstEid,
        bytes calldata options
    ) external onlyRole(GOVERNANCE_ROLE) {
        stargateSendOptions[dstEid] = options;
        emit StargateSendOptionsConfigured(dstEid, options);
    }

    function quoteTransportFee(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) external view returns (uint256 nativeFee) {
        _requireTransportConfigured();
        if (asset != stargate.token()) {
            revert StargateBridgeAdapter__UnsupportedAsset(asset);
        }

        (uint32 strategyId, address receiver) = _resolveRoute(dstEid, payload);
        strategyId; // silence stack/local variable warning semantics

        bytes memory options = stargateSendOptions[dstEid];
        if (options.length == 0) {
            revert StargateBridgeAdapter__MissingExecutorOptions(dstEid);
        }

        BridgeComposePayload memory composePayload = BridgeComposePayload({
            srcPeer: localPeer(),
            receiver: receiver,
            payload: payload
        });

        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: peers[dstEid],
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: abi.encode(composePayload),
            oftCmd: bytes("")
        });

        nativeFee = stargate.quoteSend(sendParam, false).nativeFee;
    }

    function sendAssetAndMessage(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) public payable override onlyRole(BRIDGE_ROLE) returns (bytes32 messageId) {
        if (address(stargate) == address(0) || endpointV2 == address(0)) {
            return super.sendAssetAndMessage(dstEid, asset, amount, payload);
        }
        if (peers[dstEid] == bytes32(0)) {
            revert LayerZeroBridgeAdapter__UnknownPeer(dstEid);
        }
        if (asset != stargate.token()) {
            revert StargateBridgeAdapter__UnsupportedAsset(asset);
        }

        IStargate.SendParam memory sendParam = _buildSendParam(
            dstEid,
            amount,
            payload
        );
        IStargate.MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        if (msg.value < fee.nativeFee) {
            revert StargateBridgeAdapter__InsufficientNativeFee(
                msg.value,
                fee.nativeFee
            );
        }

        if (amount != 0) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            if (stargate.approvalRequired()) {
                IERC20(asset).forceApprove(address(stargate), amount);
            }
        }

        (IStargate.MessagingReceipt memory receipt, ) = stargate.send{
            value: fee.nativeFee
        }(sendParam, fee, msg.sender);
        messageId = receipt.guid;

        _afterSend(asset, amount, payload, dstEid, receipt);
    }

    function lzCompose(
        address from,
        bytes32 guid,
        bytes calldata message,
        address,
        bytes calldata
    ) external payable override {
        if (msg.sender != endpointV2) {
            revert StargateBridgeAdapter__InvalidEndpoint(msg.sender);
        }
        if (from != address(stargate)) {
            revert StargateBridgeAdapter__InvalidComposer(from);
        }

        bytes calldata rawComposePayload = message.composeMsg();
        BridgeComposePayload memory composePayload = abi.decode(rawComposePayload, (BridgeComposePayload));
        bytes32 composeFrom = message.composeFrom();
        if (composeFrom != composePayload.srcPeer) {
            revert StargateBridgeAdapter__InvalidComposeSender(composeFrom);
        }
        _applyComposedMessage(guid, message.srcEid(), message.amountLD(), composePayload);
    }

    function _requireTransportConfigured() internal view {
        if (address(stargate) == address(0) || endpointV2 == address(0)) {
            revert StargateBridgeAdapter__TransportNotConfigured();
        }
    }

    function _resolveRoute(
        uint32 dstEid,
        bytes calldata payload
    ) internal view returns (uint32 strategyId, address receiver) {
        CrossChainTypes.CommandPayloadV1 memory command = abi.decode(
            payload,
            (CrossChainTypes.CommandPayloadV1)
        );
        strategyId = command.strategyId;
        receiver = strategyReceivers[dstEid][strategyId];
        if (receiver == address(0)) {
            revert StargateBridgeAdapter__MissingRoute(dstEid, strategyId);
        }
    }

    function _buildSendParam(
        uint32 dstEid,
        uint256 amount,
        bytes calldata payload
    ) internal view returns (IStargate.SendParam memory sendParam) {
        (, address receiver) = _resolveRoute(dstEid, payload);
        bytes memory options = stargateSendOptions[dstEid];
        if (options.length == 0) {
            revert StargateBridgeAdapter__MissingExecutorOptions(dstEid);
        }

        BridgeComposePayload memory composePayload = BridgeComposePayload({
            srcPeer: localPeer(),
            receiver: receiver,
            payload: payload
        });

        sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: peers[dstEid],
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: options,
            composeMsg: abi.encode(composePayload),
            oftCmd: bytes("")
        });
    }

    function _afterSend(
        address asset,
        uint256 amount,
        bytes calldata payload,
        uint32 dstEid,
        IStargate.MessagingReceipt memory receipt
    ) internal {
        if (amount != 0 && stargate.approvalRequired()) {
            IERC20(asset).forceApprove(address(stargate), 0);
        }

        _storeOutboundMessage(
            receipt.guid,
            receipt.nonce,
            dstEid,
            peers[dstEid],
            msg.sender,
            asset,
            amount,
            keccak256(payload)
        );

        emit MessageSent(receipt.guid, dstEid);
        emit AssetBridged(receipt.guid, dstEid, asset, amount);
    }

    function _applyComposedMessage(
        bytes32 guid,
        uint32 srcEid,
        uint256 amount,
        BridgeComposePayload memory composePayload
    ) internal {
        if (peers[srcEid] != composePayload.srcPeer) {
            revert LayerZeroBridgeAdapter__UntrustedPeer(
                srcEid,
                composePayload.srcPeer
            );
        }

        address asset = stargate.token();
        bytes32 payloadHash = keccak256(composePayload.payload);

        _storeInboundMessage(
            guid,
            srcEid,
            composePayload.srcPeer,
            composePayload.receiver,
            asset,
            amount,
            payloadHash
        );

        if (amount != 0) {
            IERC20(asset).safeTransfer(composePayload.receiver, amount);
        }

        CrossChainTypes.CommandPayloadV1 memory command = abi.decode(
            composePayload.payload,
            (CrossChainTypes.CommandPayloadV1)
        );
        if (command.commandType == CrossChainTypes.CommandType.Allocate) {
            IRemoteStrategyAgent(composePayload.receiver).receiveBridgeAsset(
                composePayload.payload
            );
        } else {
            ICrossChainVault(composePayload.receiver).receiveRecallFunds(amount);
        }

        emit MessageReceived(guid, srcEid, composePayload.receiver, payloadHash);
    }
}

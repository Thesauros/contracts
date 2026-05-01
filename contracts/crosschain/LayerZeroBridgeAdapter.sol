// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IBridgeAdapter} from "../interfaces/crosschain/IBridgeAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LayerZeroBridgeAdapter is CrossChainAccessControl, IBridgeAdapter {
    using SafeERC20 for IERC20;

    error LayerZeroBridgeAdapter__InvalidTimeout();
    error LayerZeroBridgeAdapter__UnknownPeer(uint32 eid);
    error LayerZeroBridgeAdapter__InvalidAsset();
    error LayerZeroBridgeAdapter__InvalidReceiver();
    error LayerZeroBridgeAdapter__UnknownMessage(bytes32 messageId);
    error LayerZeroBridgeAdapter__MessageAlreadyFinalized(bytes32 messageId);
    error LayerZeroBridgeAdapter__InboundReplay(bytes32 messageId);
    error LayerZeroBridgeAdapter__UntrustedPeer(uint32 srcEid, bytes32 srcPeer);
    error LayerZeroBridgeAdapter__RecoveryNotEligible(bytes32 messageId);

    struct BridgeMessage {
        bytes32 messageId;
        uint64 nonce;
        uint32 srcEid;
        uint32 dstEid;
        bytes32 srcPeer;
        bytes32 dstPeer;
        address sender;
        address receiver;
        address asset;
        uint256 amount;
        bytes32 payloadHash;
        bytes32 ackHash;
        uint64 sentAt;
        uint64 timeoutAt;
        uint64 receivedAt;
        uint64 acknowledgedAt;
        bool delivered;
        bool acknowledged;
        bool failed;
    }

    uint64 public messageTimeout = 1 days;
    uint64 public nextMessageNonce = 1;
    mapping(uint32 eid => bytes32 peer) public peers;
    mapping(bytes32 messageId => BridgeMessage) private messages;

    bytes32 private immutable LOCAL_PEER;

    constructor(address admin) CrossChainAccessControl(admin) {
        LOCAL_PEER = bytes32(uint256(uint160(address(this))));
    }

    function localPeer() public view returns (bytes32) {
        return LOCAL_PEER;
    }

    function getMessage(
        bytes32 messageId
    ) external view returns (BridgeMessage memory) {
        return messages[messageId];
    }

    function setPeer(
        uint32 eid,
        bytes32 peer
    ) external onlyRole(GOVERNANCE_ROLE) {
        peers[eid] = peer;
        emit PeerConfigured(eid, peer);
    }

    function setMessageTimeout(
        uint64 newTimeout
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (newTimeout == 0) {
            revert LayerZeroBridgeAdapter__InvalidTimeout();
        }

        uint64 previousTimeout = messageTimeout;
        messageTimeout = newTimeout;
        emit MessageTimeoutUpdated(previousTimeout, newTimeout);
    }

    function sendAssetAndMessage(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) external payable onlyRole(BRIDGE_ROLE) returns (bytes32 messageId) {
        if (peers[dstEid] == bytes32(0)) {
            revert LayerZeroBridgeAdapter__UnknownPeer(dstEid);
        }
        if (asset == address(0)) {
            revert LayerZeroBridgeAdapter__InvalidAsset();
        }

        uint64 nonce = nextMessageNonce++;
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 payloadHash = keccak256(payload);

        messageId = keccak256(
            abi.encode(
                block.chainid,
                nonce,
                dstEid,
                asset,
                amount,
                payloadHash,
                block.timestamp
            )
        );

        if (amount != 0) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }

        _storeOutboundMessage(
            messageId,
            nonce,
            dstEid,
            peers[dstEid],
            msg.sender,
            asset,
            amount,
            payloadHash
        );

        emit MessageSent(messageId, dstEid);
        emit AssetBridged(messageId, dstEid, asset, amount);
    }

    function receiveAssetAndMessage(
        uint32 srcEid,
        bytes32 srcPeer,
        bytes32 messageId,
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata payload
    ) external onlyRole(BRIDGE_ROLE) {
        if (peers[srcEid] != srcPeer) {
            revert LayerZeroBridgeAdapter__UntrustedPeer(srcEid, srcPeer);
        }
        if (asset == address(0)) {
            revert LayerZeroBridgeAdapter__InvalidAsset();
        }
        if (receiver == address(0)) {
            revert LayerZeroBridgeAdapter__InvalidReceiver();
        }
        if (messages[messageId].messageId != bytes32(0)) {
            revert LayerZeroBridgeAdapter__InboundReplay(messageId);
        }

        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 payloadHash = keccak256(payload);
        _storeInboundMessage(
            messageId,
            srcEid,
            srcPeer,
            receiver,
            asset,
            amount,
            payloadHash
        );

        if (amount != 0) {
            IERC20(asset).safeTransfer(receiver, amount);
        }

        emit MessageReceived(messageId, srcEid, receiver, payloadHash);
    }

    function acknowledgeMessage(
        bytes32 messageId,
        bytes calldata ackPayload
    ) external onlyRole(BRIDGE_ROLE) {
        BridgeMessage storage message = messages[messageId];
        if (message.messageId == bytes32(0)) {
            revert LayerZeroBridgeAdapter__UnknownMessage(messageId);
        }
        if (message.failed || message.acknowledged) {
            revert LayerZeroBridgeAdapter__MessageAlreadyFinalized(messageId);
        }

        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 ackHash = keccak256(ackPayload);
        message.ackHash = ackHash;
        message.acknowledgedAt = uint64(block.timestamp);
        message.delivered = true;
        message.acknowledged = true;

        emit MessageAcknowledged(messageId, ackHash, message.acknowledgedAt);
    }

    function isMessageRecoveryEligible(
        bytes32 messageId
    ) public view returns (bool) {
        BridgeMessage memory message = messages[messageId];
        return
            message.messageId != bytes32(0) &&
            message.sentAt != 0 &&
            !message.acknowledged &&
            !message.failed &&
            // forge-lint: disable-next-line(block-timestamp)
            block.timestamp >= message.timeoutAt;
    }

    function failMessage(
        bytes32 messageId,
        address refundReceiver
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (refundReceiver == address(0)) {
            revert LayerZeroBridgeAdapter__InvalidReceiver();
        }

        BridgeMessage storage message = messages[messageId];
        if (message.messageId == bytes32(0)) {
            revert LayerZeroBridgeAdapter__UnknownMessage(messageId);
        }
        if (message.acknowledged || message.failed) {
            revert LayerZeroBridgeAdapter__MessageAlreadyFinalized(messageId);
        }
        if (!isMessageRecoveryEligible(messageId)) {
            revert LayerZeroBridgeAdapter__RecoveryNotEligible(messageId);
        }

        message.failed = true;
        message.receiver = refundReceiver;

        if (message.amount != 0) {
            IERC20(message.asset).safeTransfer(refundReceiver, message.amount);
        }

        emit MessageFailed(messageId, refundReceiver, message.amount);
    }

    function _storeOutboundMessage(
        bytes32 messageId,
        uint64 nonce,
        uint32 dstEid,
        bytes32 dstPeer,
        address sender,
        address asset,
        uint256 amount,
        bytes32 payloadHash
    ) internal {
        BridgeMessage storage message = messages[messageId];
        message.messageId = messageId;
        message.nonce = nonce;
        message.srcEid = uint32(block.chainid);
        message.dstEid = dstEid;
        message.srcPeer = LOCAL_PEER;
        message.dstPeer = dstPeer;
        message.sender = sender;
        message.asset = asset;
        message.amount = amount;
        message.payloadHash = payloadHash;
        message.sentAt = uint64(block.timestamp);
        message.timeoutAt = uint64(block.timestamp) + messageTimeout;
    }

    function _storeInboundMessage(
        bytes32 messageId,
        uint32 srcEid,
        bytes32 srcPeer,
        address receiver,
        address asset,
        uint256 amount,
        bytes32 payloadHash
    ) internal {
        BridgeMessage storage message = messages[messageId];
        message.messageId = messageId;
        message.srcEid = srcEid;
        message.dstEid = uint32(block.chainid);
        message.srcPeer = srcPeer;
        message.dstPeer = LOCAL_PEER;
        message.receiver = receiver;
        message.asset = asset;
        message.amount = amount;
        message.payloadHash = payloadHash;
        message.receivedAt = uint64(block.timestamp);
        message.delivered = true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IBridgeAdapter {
    event PeerConfigured(uint32 indexed eid, bytes32 peer);
    event MessageTimeoutUpdated(
        uint64 previousTimeout,
        uint64 newTimeout
    );
    event MessageSent(bytes32 indexed opId, uint32 indexed dstEid);
    event AssetBridged(
        bytes32 indexed opId,
        uint32 indexed dstEid,
        address indexed asset,
        uint256 amount
    );
    event MessageReceived(
        bytes32 indexed messageId,
        uint32 indexed srcEid,
        address indexed receiver,
        bytes32 payloadHash
    );
    event MessageAcknowledged(
        bytes32 indexed messageId,
        bytes32 ackHash,
        uint64 acknowledgedAt
    );
    event MessageFailed(
        bytes32 indexed messageId,
        address indexed refundReceiver,
        uint256 refundedAmount
    );

    function messageTimeout() external view returns (uint64);

    function sendAssetAndMessage(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) external payable returns (bytes32 messageId);

    function receiveAssetAndMessage(
        uint32 srcEid,
        bytes32 srcPeer,
        bytes32 messageId,
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata payload
    ) external;

    function acknowledgeMessage(
        bytes32 messageId,
        bytes calldata ackPayload
    ) external;

    function setMessageTimeout(uint64 newTimeout) external;

    function isMessageRecoveryEligible(
        bytes32 messageId
    ) external view returns (bool);

    function failMessage(
        bytes32 messageId,
        address refundReceiver
    ) external;
}

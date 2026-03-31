// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

interface IBridgeAdapter {
    event MessageSent(bytes32 indexed opId, uint32 indexed dstEid);
    event AssetBridged(
        bytes32 indexed opId,
        uint32 indexed dstEid,
        address indexed asset,
        uint256 amount
    );

    function sendAssetAndMessage(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata payload
    ) external payable returns (bytes32 opId);
}

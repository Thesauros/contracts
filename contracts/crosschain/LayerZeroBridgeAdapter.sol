// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IBridgeAdapter} from "../interfaces/crosschain/IBridgeAdapter.sol";

contract LayerZeroBridgeAdapter is CrossChainAccessControl, IBridgeAdapter {
    error LayerZeroBridgeAdapter__NotImplemented();

    mapping(uint32 eid => bytes32 peer) public peers;

    event PeerConfigured(uint32 indexed eid, bytes32 peer);

    constructor(address admin) CrossChainAccessControl(admin) {}

    function setPeer(
        uint32 eid,
        bytes32 peer
    ) external onlyRole(GOVERNANCE_ROLE) {
        peers[eid] = peer;
        emit PeerConfigured(eid, peer);
    }

    function sendAssetAndMessage(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes calldata
    ) external payable onlyRole(BRIDGE_ROLE) returns (bytes32 opId) {
        if (peers[dstEid] == bytes32(0)) {
            revert LayerZeroBridgeAdapter__NotImplemented();
        }

        opId = keccak256(
            abi.encode(block.chainid, dstEid, asset, amount, block.timestamp)
        );

        emit MessageSent(opId, dstEid);
        emit AssetBridged(opId, dstEid, asset, amount);

        revert LayerZeroBridgeAdapter__NotImplemented();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";

contract LayerZeroBridgeAdapterTests is Test {
    LayerZeroBridgeAdapter internal adapter;
    MockERC20 internal asset;

    address internal bridge = makeAddr("bridge");
    address internal receiver = makeAddr("receiver");

    uint32 internal constant REMOTE_EID = 30_101;
    bytes32 internal constant REMOTE_PEER = bytes32(uint256(0xBEEF));

    function setUp() public {
        adapter = new LayerZeroBridgeAdapter(address(this));
        asset = new MockERC20("USD Coin", "USDC", 6);

        adapter.grantRole(adapter.BRIDGE_ROLE(), bridge);
        adapter.setPeer(REMOTE_EID, REMOTE_PEER);

        asset.mint(bridge, 1_000_000e6);
    }

    function testSendAssetAndMessageEscrowsAssetAndStoresMessage() public {
        bytes memory payload = abi.encode("allocate");

        vm.startPrank(bridge);
        asset.approve(address(adapter), type(uint256).max);
        bytes32 messageId = adapter.sendAssetAndMessage(
            REMOTE_EID,
            address(asset),
            100e6,
            payload
        );
        vm.stopPrank();

        LayerZeroBridgeAdapter.BridgeMessage memory message = adapter.getMessage(
            messageId
        );

        assertEq(message.messageId, messageId);
        assertEq(message.nonce, 1);
        assertEq(message.srcEid, uint32(block.chainid));
        assertEq(message.dstEid, REMOTE_EID);
        assertEq(message.srcPeer, adapter.localPeer());
        assertEq(message.dstPeer, REMOTE_PEER);
        assertEq(message.sender, bridge);
        assertEq(message.receiver, address(0));
        assertEq(message.asset, address(asset));
        assertEq(message.amount, 100e6);
        assertEq(message.payloadHash, keccak256(payload));
        assertEq(message.sentAt, block.timestamp);
        assertEq(message.receivedAt, 0);
        assertFalse(message.delivered);
        assertFalse(message.failed);
        assertEq(asset.balanceOf(address(adapter)), 100e6);
        assertEq(asset.balanceOf(bridge), 1_000_000e6 - 100e6);
    }

    function testSendAssetAndMessageRejectsUnknownPeer() public {
        vm.startPrank(bridge);
        asset.approve(address(adapter), type(uint256).max);
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroBridgeAdapter.LayerZeroBridgeAdapter__UnknownPeer.selector,
                uint32(999)
            )
        );
        adapter.sendAssetAndMessage(999, address(asset), 1e6, bytes(""));
        vm.stopPrank();
    }

    function testReceiveAssetAndMessageTransfersFundsToReceiver() public {
        bytes32 messageId = keccak256("remote-message");
        bytes memory payload = abi.encode("recall");

        asset.mint(address(adapter), 25e6);

        vm.prank(bridge);
        adapter.receiveAssetAndMessage(
            REMOTE_EID,
            REMOTE_PEER,
            messageId,
            address(asset),
            25e6,
            receiver,
            payload
        );

        LayerZeroBridgeAdapter.BridgeMessage memory message = adapter.getMessage(
            messageId
        );

        assertEq(message.messageId, messageId);
        assertEq(message.srcEid, REMOTE_EID);
        assertEq(message.dstEid, uint32(block.chainid));
        assertEq(message.srcPeer, REMOTE_PEER);
        assertEq(message.dstPeer, adapter.localPeer());
        assertEq(message.receiver, receiver);
        assertEq(message.asset, address(asset));
        assertEq(message.amount, 25e6);
        assertEq(message.payloadHash, keccak256(payload));
        assertEq(message.receivedAt, block.timestamp);
        assertTrue(message.delivered);
        assertFalse(message.failed);
        assertEq(asset.balanceOf(receiver), 25e6);
    }

    function testReceiveAssetAndMessageRejectsReplay() public {
        bytes32 messageId = keccak256("remote-message");

        vm.prank(bridge);
        adapter.receiveAssetAndMessage(
            REMOTE_EID,
            REMOTE_PEER,
            messageId,
            address(asset),
            0,
            receiver,
            bytes("")
        );

        vm.prank(bridge);
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroBridgeAdapter.LayerZeroBridgeAdapter__InboundReplay.selector,
                messageId
            )
        );
        adapter.receiveAssetAndMessage(
            REMOTE_EID,
            REMOTE_PEER,
            messageId,
            address(asset),
            0,
            receiver,
            bytes("")
        );
    }

    function testMessageFailureRefundsEscrow() public {
        bytes memory payload = abi.encode("allocate");

        vm.startPrank(bridge);
        asset.approve(address(adapter), type(uint256).max);
        bytes32 messageId = adapter.sendAssetAndMessage(
            REMOTE_EID,
            address(asset),
            40e6,
            payload
        );
        vm.stopPrank();

        adapter.failMessage(messageId, receiver);

        LayerZeroBridgeAdapter.BridgeMessage memory message = adapter.getMessage(
            messageId
        );

        assertEq(message.receiver, receiver);
        assertEq(message.amount, 40e6);
        assertFalse(message.delivered);
        assertTrue(message.failed);
        assertEq(asset.balanceOf(receiver), 40e6);
        assertEq(asset.balanceOf(address(adapter)), 0);
    }
}

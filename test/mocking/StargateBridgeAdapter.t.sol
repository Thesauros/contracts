// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";
import {
    StargateBridgeAdapter,
    ILayerZeroComposer,
    IStargate
} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockStrategyAdapter} from "../../contracts/mocks/MockStrategyAdapter.sol";

contract MockEndpointV2 {
    function deliverCompose(
        address composer,
        address from,
        bytes32 guid,
        bytes calldata message
    ) external {
        ILayerZeroComposer(composer).lzCompose(
            from,
            guid,
            message,
            address(this),
            bytes("")
        );
    }
}

contract MockRecallVault {
    uint256 public receivedAssets;

    function receiveRecallFunds(uint256 assets) external {
        receivedAssets += assets;
    }
}

contract MockStargateTransport is IStargate {
    using SafeERC20 for IERC20;

    uint32 public immutable localEid;
    address public immutable endpoint;
    address public immutable underlyingToken;

    uint64 internal nextNonce = 1;
    mapping(uint32 dstEid => address remoteStargate) public remoteStargates;

    constructor(uint32 localEid_, address endpoint_, address token_) {
        localEid = localEid_;
        endpoint = endpoint_;
        underlyingToken = token_;
    }

    function setRemoteStargate(uint32 dstEid, address remoteStargate) external {
        remoteStargates[dstEid] = remoteStargate;
    }

    function token() external view returns (address) {
        return underlyingToken;
    }

    function approvalRequired() external pure returns (bool) {
        return true;
    }

    function quoteSend(
        SendParam calldata,
        bool
    ) external pure returns (MessagingFee memory) {
        return MessagingFee({nativeFee: 1 wei, lzTokenFee: 0});
    }

    function send(
        SendParam calldata sendParam,
        MessagingFee calldata fee,
        address
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        require(msg.value >= fee.nativeFee, "fee");

        uint64 nonce = nextNonce++;
        bytes32 guid = keccak256(
            abi.encode(
                localEid,
                nonce,
                msg.sender,
                sendParam.dstEid,
                sendParam.to,
                sendParam.amountLD,
                sendParam.composeMsg
            )
        );

        address receiver = address(uint160(uint256(sendParam.to)));
        IERC20(underlyingToken).safeTransferFrom(msg.sender, receiver, sendParam.amountLD);

        bytes memory composeMessage = abi.encodePacked(
            nonce,
            localEid,
            sendParam.amountLD,
            bytes32(uint256(uint160(msg.sender))),
            sendParam.composeMsg
        );

        MockEndpointV2(endpoint).deliverCompose(
            receiver,
            remoteStargates[sendParam.dstEid],
            guid,
            composeMessage
        );

        msgReceipt = MessagingReceipt({
            guid: guid,
            nonce: nonce,
            fee: fee
        });
        oftReceipt = OFTReceipt({
            amountSentLD: sendParam.amountLD,
            amountReceivedLD: sendParam.amountLD
        });
    }
}

contract StargateBridgeAdapterTests is Test {
    uint32 internal constant HOME_EID = 30_184;
    uint32 internal constant REMOTE_EID = 30_110;
    uint32 internal constant STRATEGY_ID = 1;

    address internal bridgeOperator = makeAddr("bridgeOperator");

    MockERC20 internal asset;
    MockEndpointV2 internal endpoint;
    MockStargateTransport internal homeStargate;
    MockStargateTransport internal remoteStargate;

    StargateBridgeAdapter internal homeBridge;
    StargateBridgeAdapter internal remoteBridge;
    RemoteStrategyAgent internal remoteAgent;
    MockStrategyAdapter internal strategyAdapter;
    MockRecallVault internal recallVault;

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        endpoint = new MockEndpointV2();
        homeStargate = new MockStargateTransport(
            HOME_EID,
            address(endpoint),
            address(asset)
        );
        remoteStargate = new MockStargateTransport(
            REMOTE_EID,
            address(endpoint),
            address(asset)
        );

        homeStargate.setRemoteStargate(REMOTE_EID, address(remoteStargate));
        remoteStargate.setRemoteStargate(HOME_EID, address(homeStargate));

        homeBridge = new StargateBridgeAdapter(address(this));
        remoteBridge = new StargateBridgeAdapter(address(this));
        strategyAdapter = new MockStrategyAdapter(address(asset));
        remoteAgent = new RemoteStrategyAgent(address(this), STRATEGY_ID);
        recallVault = new MockRecallVault();

        remoteAgent.grantRole(remoteAgent.BRIDGE_ROLE(), address(remoteBridge));
        remoteAgent.setAsset(address(asset));
        remoteAgent.setStrategyAdapter(address(strategyAdapter));

        homeBridge.grantRole(homeBridge.BRIDGE_ROLE(), bridgeOperator);
        remoteBridge.grantRole(remoteBridge.BRIDGE_ROLE(), bridgeOperator);

        homeBridge.setPeer(REMOTE_EID, remoteBridge.localPeer());
        remoteBridge.setPeer(HOME_EID, homeBridge.localPeer());

        homeBridge.setTransport(address(homeStargate), address(endpoint));
        remoteBridge.setTransport(address(remoteStargate), address(endpoint));

        homeBridge.setSendOptions(REMOTE_EID, hex"0001");
        remoteBridge.setSendOptions(HOME_EID, hex"0001");

        homeBridge.setStrategyReceiver(
            REMOTE_EID,
            STRATEGY_ID,
            address(remoteAgent)
        );
        remoteBridge.setStrategyReceiver(
            HOME_EID,
            STRATEGY_ID,
            address(recallVault)
        );

        asset.mint(bridgeOperator, 1_000_000e6);
        vm.deal(bridgeOperator, 1 ether);
    }

    function testSendAssetAndMessageDeliversAllocateThroughStargate() public {
        bytes memory payload = _commandPayload(
            CrossChainTypes.CommandType.Allocate,
            125e6
        );

        vm.startPrank(bridgeOperator);
        asset.approve(address(homeBridge), type(uint256).max);
        bytes32 messageId = homeBridge.sendAssetAndMessage{value: 1 wei}(
            REMOTE_EID,
            address(asset),
            125e6,
            payload
        );
        vm.stopPrank();

        StargateBridgeAdapter.BridgeMessage memory outbound = homeBridge
            .getMessage(messageId);
        StargateBridgeAdapter.BridgeMessage memory inbound = remoteBridge
            .getMessage(messageId);

        assertEq(outbound.messageId, messageId);
        assertEq(outbound.dstEid, REMOTE_EID);
        assertEq(outbound.amount, 125e6);
        assertEq(outbound.payloadHash, keccak256(payload));

        assertEq(inbound.messageId, messageId);
        assertEq(inbound.srcEid, HOME_EID);
        assertEq(inbound.receiver, address(remoteAgent));
        assertEq(inbound.amount, 125e6);
        assertTrue(inbound.delivered);

        assertEq(remoteAgent.idleAssets(), 125e6);
        assertEq(asset.balanceOf(address(remoteAgent)), 125e6);
        assertEq(asset.balanceOf(address(homeBridge)), 0);
        assertEq(asset.balanceOf(address(remoteBridge)), 0);
    }

    function testSendAssetAndMessageDeliversRecallThroughStargate() public {
        bytes memory payload = _commandPayload(
            CrossChainTypes.CommandType.Recall,
            55e6
        );

        vm.startPrank(bridgeOperator);
        asset.approve(address(remoteBridge), type(uint256).max);
        bytes32 messageId = remoteBridge.sendAssetAndMessage{value: 1 wei}(
            HOME_EID,
            address(asset),
            55e6,
            payload
        );
        vm.stopPrank();

        StargateBridgeAdapter.BridgeMessage memory inbound = homeBridge
            .getMessage(messageId);

        assertEq(inbound.srcEid, REMOTE_EID);
        assertEq(inbound.receiver, address(recallVault));
        assertEq(inbound.amount, 55e6);
        assertTrue(inbound.delivered);

        assertEq(recallVault.receivedAssets(), 55e6);
        assertEq(asset.balanceOf(address(recallVault)), 55e6);
    }

    function testLzComposeRejectsUnknownEndpoint() public {
        bytes memory payload = abi.encode(
            bytes32(uint256(uint160(address(homeBridge)))),
            address(remoteAgent),
            _commandPayload(CrossChainTypes.CommandType.Allocate, 1e6)
        );
        bytes memory composeMessage = abi.encodePacked(
            uint64(1),
            HOME_EID,
            uint256(1e6),
            bytes32(uint256(uint160(address(homeBridge)))),
            payload
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StargateBridgeAdapter
                    .StargateBridgeAdapter__InvalidEndpoint
                    .selector,
                address(this)
            )
        );
        remoteBridge.lzCompose(
            address(remoteStargate),
            keccak256("guid"),
            composeMessage,
            address(0),
            bytes("")
        );
    }

    function _commandPayload(
        CrossChainTypes.CommandType commandType,
        uint256 assets
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                CrossChainTypes.CommandPayloadV1({
                    version: 1,
                    opId: keccak256(abi.encode(commandType, assets)),
                    strategyId: STRATEGY_ID,
                    sourceChainId: HOME_EID,
                    commandType: commandType,
                    assets: assets,
                    minAssetsOut: assets,
                    deadline: uint64(block.timestamp + 1 days),
                    commandTimestamp: uint64(block.timestamp),
                    params: bytes("")
                })
            );
    }
}

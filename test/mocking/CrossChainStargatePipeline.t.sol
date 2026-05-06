// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {StargateBridgeAdapter, ILayerZeroComposer, IStargate} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockStrategyAdapter} from "../../contracts/mocks/MockStrategyAdapter.sol";

contract PipelineMockEndpointV2 {
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

contract PipelineMockStargateTransport is IStargate {
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

    function quoteOFT(
        SendParam calldata sendParam
    )
        external
        pure
        returns (
            OFTLimit memory limit,
            OFTFeeDetail[] memory oftFeeDetails,
            OFTReceipt memory receipt
        )
    {
        limit = OFTLimit({minAmountLD: 1, maxAmountLD: type(uint256).max});
        oftFeeDetails = new OFTFeeDetail[](0);
        receipt = OFTReceipt({
            amountSentLD: sendParam.amountLD,
            amountReceivedLD: sendParam.amountLD == 0
                ? 0
                : sendParam.amountLD - 1
        });
    }

    function quoteSend(
        SendParam calldata sendParam,
        bool
    ) external pure returns (MessagingFee memory) {
        if (
            sendParam.amountLD != 0 &&
            sendParam.minAmountLD >= sendParam.amountLD
        ) revert("slippage");
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

        uint256 amountReceivedLD = sendParam.amountLD == 0
            ? 0
            : sendParam.amountLD - 1;
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
        IERC20(underlyingToken).safeTransferFrom(
            msg.sender,
            address(this),
            sendParam.amountLD
        );
        IERC20(underlyingToken).safeTransfer(receiver, amountReceivedLD);

        bytes memory composeMessage = abi.encodePacked(
            nonce,
            localEid,
            amountReceivedLD,
            bytes32(uint256(uint160(msg.sender))),
            sendParam.composeMsg
        );

        PipelineMockEndpointV2(endpoint).deliverCompose(
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
            amountReceivedLD: amountReceivedLD
        });
    }
}

contract CrossChainStargatePipelineTests is Test {
    uint32 internal constant STRATEGY_ID = 3;
    uint32 internal constant HOME_EID = 30_184;
    uint32 internal constant REMOTE_EID = 30_110;
    uint256 internal constant DEPOSIT_AMOUNT = 180e6;
    uint256 internal constant ALLOCATE_AMOUNT = 70e6;
    uint256 internal constant YIELD_AMOUNT = 8e6;

    address internal alice = makeAddr("alice");
    address internal keeper = makeAddr("keeper");
    address internal reporter = makeAddr("reporter");

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    ReportSettler internal settler;
    WithdrawalQueue internal queue;
    CrossChainVault internal vault;
    StargateBridgeAdapter internal homeBridge;
    StargateBridgeAdapter internal remoteBridge;
    RemoteStrategyAgent internal remoteAgent;
    MockStrategyAdapter internal strategyAdapter;
    PipelineMockEndpointV2 internal endpoint;
    PipelineMockStargateTransport internal homeStargate;
    PipelineMockStargateTransport internal remoteStargate;

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        registry = new StrategyRegistry(address(this));
        allocator = new StrategyAllocator(address(this), registry);
        queue = new WithdrawalQueue(address(this));
        settler = new ReportSettler(address(this), registry);
        vault = new CrossChainVault(
            asset,
            "CrossChain Vault",
            "ccUSDC",
            address(this),
            registry,
            allocator,
            settler,
            queue
        );
        endpoint = new PipelineMockEndpointV2();
        homeStargate = new PipelineMockStargateTransport(
            HOME_EID,
            address(endpoint),
            address(asset)
        );
        remoteStargate = new PipelineMockStargateTransport(
            REMOTE_EID,
            address(endpoint),
            address(asset)
        );
        homeBridge = new StargateBridgeAdapter(address(this));
        remoteBridge = new StargateBridgeAdapter(address(this));
        remoteAgent = new RemoteStrategyAgent(address(this), STRATEGY_ID);
        strategyAdapter = new MockStrategyAdapter(address(asset));

        homeStargate.setRemoteStargate(REMOTE_EID, address(remoteStargate));
        remoteStargate.setRemoteStargate(HOME_EID, address(homeStargate));

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));
        settler.grantRole(settler.REPORTER_ROLE(), reporter);
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        homeBridge.grantRole(homeBridge.BRIDGE_ROLE(), address(vault));
        remoteAgent.grantRole(remoteAgent.BRIDGE_ROLE(), address(remoteBridge));
        remoteAgent.grantRole(remoteAgent.KEEPER_ROLE(), keeper);
        remoteAgent.grantRole(remoteAgent.REPORTER_ROLE(), reporter);
        remoteAgent.setAsset(address(asset));
        remoteAgent.setStrategyAdapter(address(strategyAdapter));

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

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: REMOTE_EID,
                agent: address(remoteAgent),
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 50,
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );

        asset.mint(alice, 1_000_000e6);
        vm.deal(keeper, 1 ether);
    }

    function testStargateAllocateLifecycleSettlesUsingDeliveredAmount() public {
        uint256 deliveredAmount = ALLOCATE_AMOUNT - 1;

        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        bytes32 allocateOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            ALLOCATE_AMOUNT,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            allocateOpId,
            CrossChainTypes.OperationStatus.Sent
        );
        vm.prank(keeper);
        vault.syncOperationAccounting(allocateOpId);

        vm.prank(keeper);
        vault.dispatchRemoteOperation{value: 1 wei}(
            allocateOpId,
            address(homeBridge),
            bytes("stargate-allocate")
        );

        CrossChainTypes.OperationDispatch memory dispatchState = allocator
            .getOperationDispatch(allocateOpId);
        bytes memory allocatePayload = allocator.encodeCommandPayload(
            allocateOpId,
            dispatchState.dispatchedAt,
            bytes("stargate-allocate")
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            allocateOpId,
            CrossChainTypes.OperationStatus.Received
        );

        vm.prank(keeper);
        remoteAgent.executeAllocate(allocatePayload);

        vm.startPrank(keeper);
        allocator.setOperationStatus(
            allocateOpId,
            CrossChainTypes.OperationStatus.Executed
        );
        allocator.setOperationStatus(
            allocateOpId,
            CrossChainTypes.OperationStatus.Settled
        );
        vm.stopPrank();

        vm.prank(keeper);
        vault.syncOperationAccounting(allocateOpId);

        assertEq(remoteAgent.deployedAssets(), deliveredAmount);
        assertEq(strategyAdapter.deployedBalance(), deliveredAmount);
        assertEq(asset.balanceOf(address(remoteBridge)), 0);

        strategyAdapter.setReportingState(
            deliveredAmount + YIELD_AMOUNT,
            deliveredAmount + YIELD_AMOUNT
        );

        vm.prank(reporter);
        CrossChainTypes.StrategyReport memory report = remoteAgent
            .prepareStrategyReport(REMOTE_EID, keccak256("stargate-position"));

        vm.prank(reporter);
        settler.submitReport(report);

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        CrossChainTypes.StrategyState memory reportedState = registry
            .getStrategyState(STRATEGY_ID);
        assertEq(reportedState.currentDebt, deliveredAmount);
        assertEq(reportedState.lastReportedValue, deliveredAmount + YIELD_AMOUNT);
        assertEq(reportedState.freeLiquidity, deliveredAmount + YIELD_AMOUNT);
        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT - ALLOCATE_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT + YIELD_AMOUNT - 1);
    }
}

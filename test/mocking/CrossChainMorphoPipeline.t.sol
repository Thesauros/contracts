// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockMetaMorphoVault} from "../../contracts/mocks/MockMetaMorphoVault.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";
import {MorphoStrategyAdapter} from "../../contracts/crosschain/MorphoStrategyAdapter.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract CrossChainMorphoPipelineTests is Test {
    uint32 internal constant STRATEGY_ID = 1;
    uint32 internal constant HOME_EID = 30_184;
    uint32 internal constant REMOTE_EID = 30_101;
    uint256 internal constant DEPOSIT_AMOUNT = 200e6;
    uint256 internal constant ALLOCATE_AMOUNT = 80e6;
    uint256 internal constant RECALL_AMOUNT = 30e6;

    MockERC20 internal asset;
    MockMetaMorphoVault internal metaMorpho;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    ReportSettler internal settler;
    WithdrawalQueue internal queue;
    CrossChainVault internal vault;
    LayerZeroBridgeAdapter internal homeBridge;
    LayerZeroBridgeAdapter internal remoteBridge;
    RemoteStrategyAgent internal remoteAgent;
    MorphoStrategyAdapter internal morphoAdapter;

    address internal alice = makeAddr("alice");
    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        metaMorpho = new MockMetaMorphoVault(asset);
        registry = new StrategyRegistry(address(this));
        allocator = new StrategyAllocator(address(this));
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
        homeBridge = new LayerZeroBridgeAdapter(address(this));
        remoteBridge = new LayerZeroBridgeAdapter(address(this));
        remoteAgent = new RemoteStrategyAgent(address(this), STRATEGY_ID);
        morphoAdapter = new MorphoStrategyAdapter(address(metaMorpho));

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), bridge);
        queue.grantRole(queue.VAULT_ROLE(), address(vault));
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);
        homeBridge.grantRole(homeBridge.BRIDGE_ROLE(), bridge);
        homeBridge.grantRole(homeBridge.BRIDGE_ROLE(), address(vault));
        remoteBridge.grantRole(remoteBridge.BRIDGE_ROLE(), bridge);
        remoteBridge.grantRole(remoteBridge.BRIDGE_ROLE(), address(remoteAgent));
        remoteAgent.grantRole(remoteAgent.BRIDGE_ROLE(), bridge);
        remoteAgent.grantRole(remoteAgent.KEEPER_ROLE(), keeper);

        remoteAgent.setAsset(address(asset));
        remoteAgent.setStrategyAdapter(address(morphoAdapter));

        homeBridge.setPeer(REMOTE_EID, remoteBridge.localPeer());
        remoteBridge.setPeer(HOME_EID, homeBridge.localPeer());

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
    }

    function testAllocateAndRecallLifecycleAcrossBridgeAndMorpho() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

        bytes32 allocateOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            ALLOCATE_AMOUNT,
            0,
            uint64(block.timestamp + 1 days)
        );

        bytes memory allocatePayload = allocator.encodeCommandPayload(
            allocateOpId,
            uint64(block.timestamp),
            bytes("morpho-allocate")
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            allocateOpId,
            CrossChainTypes.OperationStatus.Sent
        );
        vm.prank(keeper);
        vault.syncOperationAccounting(allocateOpId);

        vm.startPrank(address(vault));
        asset.approve(address(homeBridge), ALLOCATE_AMOUNT);
        bytes32 allocateMessageId = homeBridge.sendAssetAndMessage(
            REMOTE_EID,
            address(asset),
            ALLOCATE_AMOUNT,
            allocatePayload
        );
        vm.stopPrank();

        vm.prank(bridge);
        allocator.registerBridgeDispatch(
            allocateOpId,
            REMOTE_EID,
            address(remoteAgent),
            allocateMessageId,
            allocatePayload
        );

        asset.mint(address(remoteBridge), ALLOCATE_AMOUNT);

        bytes32 homePeer = homeBridge.localPeer();

        vm.prank(bridge);
        remoteBridge.receiveAssetAndMessage(
            HOME_EID,
            homePeer,
            allocateMessageId,
            address(asset),
            ALLOCATE_AMOUNT,
            address(remoteAgent),
            allocatePayload
        );

        vm.prank(bridge);
        homeBridge.acknowledgeMessage(allocateMessageId, allocatePayload);

        vm.prank(bridge);
        remoteAgent.receiveBridgeAsset(allocatePayload);

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

        CrossChainTypes.StrategyState memory allocateState = registry
            .getStrategyState(STRATEGY_ID);
        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT - ALLOCATE_AMOUNT);
        assertEq(allocateState.pendingBridgeOut, 0);
        assertEq(allocateState.currentDebt, ALLOCATE_AMOUNT);
        assertEq(remoteAgent.idleAssets(), 0);
        assertEq(remoteAgent.deployedAssets(), ALLOCATE_AMOUNT);
        assertEq(morphoAdapter.totalValue(), ALLOCATE_AMOUNT);

        bytes32 recallOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            RECALL_AMOUNT,
            RECALL_AMOUNT,
            uint64(block.timestamp + 1 days)
        );

        bytes memory recallPayload = allocator.encodeCommandPayload(
            recallOpId,
            uint64(block.timestamp),
            bytes("morpho-recall")
        );

        vm.prank(bridge);
        bytes32 recallDispatchMessageId = homeBridge.sendAssetAndMessage(
            REMOTE_EID,
            address(asset),
            0,
            recallPayload
        );

        vm.prank(bridge);
        allocator.registerBridgeDispatch(
            recallOpId,
            REMOTE_EID,
            address(remoteAgent),
            recallDispatchMessageId,
            recallPayload
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Sent
        );

        vm.prank(bridge);
        remoteBridge.receiveAssetAndMessage(
            HOME_EID,
            homePeer,
            recallDispatchMessageId,
            address(asset),
            0,
            address(remoteAgent),
            recallPayload
        );

        vm.prank(bridge);
        remoteAgent.receiveBridgeAsset(recallPayload);

        vm.prank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Received
        );

        vm.prank(keeper);
        remoteAgent.executeRecall(recallPayload);

        vm.prank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Executed
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(recallOpId);

        vm.prank(bridge);
        bytes32 recallReturnMessageId = remoteAgent.bridgeAssetsHome(
            recallPayload,
            address(remoteBridge),
            HOME_EID
        );

        asset.mint(address(homeBridge), RECALL_AMOUNT);

        bytes32 remotePeer = remoteBridge.localPeer();

        vm.prank(bridge);
        homeBridge.receiveAssetAndMessage(
            REMOTE_EID,
            remotePeer,
            recallReturnMessageId,
            address(asset),
            RECALL_AMOUNT,
            address(vault),
            recallPayload
        );

        vm.prank(bridge);
        remoteBridge.acknowledgeMessage(recallReturnMessageId, recallPayload);

        vm.prank(bridge);
        vault.receiveRecallFunds(RECALL_AMOUNT);

        vm.prank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Settled
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(recallOpId);

        CrossChainTypes.StrategyState memory recallState = registry
            .getStrategyState(STRATEGY_ID);
        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT - ALLOCATE_AMOUNT + RECALL_AMOUNT);
        assertEq(recallState.currentDebt, ALLOCATE_AMOUNT - RECALL_AMOUNT);
        assertEq(recallState.pendingBridgeIn, 0);
        assertEq(remoteAgent.idleAssets(), 0);
        assertEq(remoteAgent.deployedAssets(), ALLOCATE_AMOUNT - RECALL_AMOUNT);
        assertEq(morphoAdapter.totalValue(), ALLOCATE_AMOUNT - RECALL_AMOUNT);
    }

    function _depositAsAlice(uint256 assets_) internal {
        vm.startPrank(alice);
        asset.approve(address(vault), assets_);
        vault.deposit(assets_, alice);
        vm.stopPrank();
    }
}

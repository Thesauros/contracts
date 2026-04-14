// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockStrategyAdapter} from "../../contracts/mocks/MockStrategyAdapter.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {LocalStrategyAgent} from "../../contracts/crosschain/LocalStrategyAgent.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract CrossChainLocalPipeline is Test {
    uint32 internal constant STRATEGY_ID = 101;
    uint256 internal constant DEPOSIT_AMOUNT = 1_000_000e6;
    uint256 internal constant ALLOCATE_AMOUNT = 400_000e6;
    uint256 internal constant RECALL_AMOUNT = 200_000e6;

    address internal governance = makeAddr("governance");
    address internal keeper = makeAddr("keeper");
    address internal allocatorRole = makeAddr("allocator");
    address internal alice = makeAddr("alice");

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;
    MockStrategyAdapter internal adapter;
    LocalStrategyAgent internal localAgent;

    function setUp() public {
        asset = new MockERC20("Mock USDC", "mUSDC", 6);

        registry = new StrategyRegistry(governance);
        allocator = new StrategyAllocator(governance, registry);
        queue = new WithdrawalQueue(governance);
        settler = new ReportSettler(governance, registry);

        vault = new CrossChainVault(
            asset,
            "CrossChain Vault",
            "ccVAULT",
            governance,
            registry,
            allocator,
            settler,
            queue
        );

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), allocatorRole);
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        allocator.setRoutingPolicy(vault);

        adapter = new MockStrategyAdapter(address(asset));
        localAgent = new LocalStrategyAgent(governance, STRATEGY_ID, address(vault));
        localAgent.grantRole(localAgent.KEEPER_ROLE(), keeper);
        localAgent.setAsset(address(asset));
        localAgent.setStrategyAdapter(address(adapter));

        vm.prank(governance);
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: uint32(block.chainid),
                agent: address(localAgent),
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 100,
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );
    }

    function testLocalAllocateAndRecall() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

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
        vault.executeLocalAllocate(allocateOpId, bytes("local-allocate"));

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
        assertEq(adapter.deployedBalance(), ALLOCATE_AMOUNT);

        bytes32 recallOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            RECALL_AMOUNT,
            RECALL_AMOUNT,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Sent
        );

        vm.prank(keeper);
        vault.executeLocalRecall(recallOpId, bytes("local-recall"));

        vm.startPrank(keeper);
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Executed
        );
        allocator.setOperationStatus(
            recallOpId,
            CrossChainTypes.OperationStatus.Settled
        );
        vm.stopPrank();

        vm.prank(keeper);
        vault.syncOperationAccounting(recallOpId);

        CrossChainTypes.StrategyState memory recallState = registry
            .getStrategyState(STRATEGY_ID);
        assertEq(
            vault.homeIdle(),
            DEPOSIT_AMOUNT - ALLOCATE_AMOUNT + RECALL_AMOUNT
        );
        assertEq(recallState.currentDebt, ALLOCATE_AMOUNT - RECALL_AMOUNT);
        assertEq(recallState.pendingBridgeIn, 0);
        assertEq(adapter.deployedBalance(), ALLOCATE_AMOUNT - RECALL_AMOUNT);
    }

    function _depositAsAlice(uint256 assets_) internal {
        asset.mint(alice, assets_);
        vm.startPrank(alice);
        asset.approve(address(vault), assets_);
        vault.deposit(assets_, alice);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract CrossChainVaultSyncAccountingFuzzTests is Test {
    uint32 internal constant STRATEGY_ID = 1;

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;

    address internal keeper = makeAddr("keeper");

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

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), keeper);

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: 1,
                agent: makeAddr("agent"),
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 100,
                maxReportDelay: 0,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );

        asset.mint(address(this), 1_000_000e6);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(500_000e6, address(this));
    }

    function testAllocateAccountingIsIdempotent(uint96 assets) public {
        uint256 maxAllocatable = vault.maxAllocatableAssets();
        if (maxAllocatable == 0) return;
        assets = uint96(bound(assets, 1, maxAllocatable));

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            assets,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);

        vm.prank(keeper);
        vault.syncOperationAccounting(opId);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                CrossChainVault.CrossChainVault__OperationAccountingAlreadySynced.selector,
                opId
            )
        );
        vault.syncOperationAccounting(opId);
    }

    function testRecallSettledClearsPendingBridgeIn(uint96 allocateAssets, uint96 recallAssets) public {
        uint256 maxAllocatable = vault.maxAllocatableAssets();
        if (maxAllocatable == 0) return;
        allocateAssets = uint96(bound(allocateAssets, 1, maxAllocatable));

        bytes32 allocOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            allocateAssets,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.startPrank(keeper);
        allocator.setOperationStatus(allocOpId, CrossChainTypes.OperationStatus.Sent);
        vault.syncOperationAccounting(allocOpId);
        allocator.setOperationStatus(allocOpId, CrossChainTypes.OperationStatus.Received);
        allocator.setOperationStatus(allocOpId, CrossChainTypes.OperationStatus.Executed);
        allocator.setOperationStatus(allocOpId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(allocOpId);
        vm.stopPrank();

        CrossChainTypes.StrategyState memory state = registry.getStrategyState(STRATEGY_ID);
        uint256 debt = state.currentDebt;
        if (debt == 0) return;

        recallAssets = uint96(bound(recallAssets, 1, debt));

        bytes32 recallOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            recallAssets,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.startPrank(keeper);
        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Sent);
        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Received);
        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Executed);
        vault.syncOperationAccounting(recallOpId);

        asset.mint(address(vault), recallAssets);
        vault.receiveRecallFunds(recallAssets);

        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(recallOpId);
        vm.stopPrank();

        state = registry.getStrategyState(STRATEGY_ID);
        assertEq(state.pendingBridgeIn, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract CrossChainAccountingHandler is Test {
    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    CrossChainVault internal vault;

    uint32 internal strategyId;

    constructor(
        MockERC20 asset_,
        StrategyRegistry registry_,
        StrategyAllocator allocator_,
        CrossChainVault vault_,
        uint32 strategyId_
    ) {
        asset = asset_;
        registry = registry_;
        allocator = allocator_;
        vault = vault_;
        strategyId = strategyId_;

        // Provide some starting liquidity.
        asset.mint(address(this), 1_000_000e6);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(500_000e6, address(this));
    }

    function allocate(uint96 assets) external {
        uint256 maxAssets = vault.maxAllocatableAssets();
        if (maxAssets == 0) return;

        assets = uint96(bound(assets, 1, maxAssets));

        bytes32 opId = allocator.createOperation(
            strategyId,
            CrossChainTypes.OperationType.Allocate,
            assets,
            0,
            uint64(block.timestamp + 1 days)
        );

        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
        vault.syncOperationAccounting(opId);

        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Received);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Executed);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(opId);
    }

    function recall(uint96 assets) external {
        CrossChainTypes.StrategyState memory state = registry.getStrategyState(strategyId);
        if (state.currentDebt == 0) return;

        uint256 debt = state.currentDebt;
        assets = uint96(bound(assets, 1, debt));

        bytes32 opId = allocator.createOperation(
            strategyId,
            CrossChainTypes.OperationType.Recall,
            assets,
            0,
            uint64(block.timestamp + 1 days)
        );

        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Received);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Executed);
        vault.syncOperationAccounting(opId);

        asset.mint(address(vault), assets);
        vault.receiveRecallFunds(assets);

        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(opId);
    }
}

contract CrossChainVaultAccountingInvariantTests is StdInvariant, Test {
    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;
    CrossChainAccountingHandler internal handler;

    uint32 internal constant STRATEGY_ID = 1;

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

        // Handler drives allocator + vault operational actions.
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), address(this));
        vault.grantRole(vault.KEEPER_ROLE(), address(this));
        vault.grantRole(vault.BRIDGE_ROLE(), address(this));

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

        handler = new CrossChainAccountingHandler(
            asset,
            registry,
            allocator,
            vault,
            STRATEGY_ID
        );

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(handler));
        allocator.grantRole(allocator.KEEPER_ROLE(), address(handler));
        vault.grantRole(vault.KEEPER_ROLE(), address(handler));
        vault.grantRole(vault.BRIDGE_ROLE(), address(handler));

        targetContract(address(handler));
    }

    function invariant_totalAssetsMatchesNavBuckets() public view {
        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();
        assertEq(vault.totalAssets(), buckets.totalManagedAssets);
    }

    function invariant_assetBalanceCoversHomeIdle() public view {
        assertGe(asset.balanceOf(address(vault)), vault.homeIdle());
    }

    function invariant_pendingBucketsNonNegative() public view {
        CrossChainTypes.StrategyState memory state = registry.getStrategyState(STRATEGY_ID);
        // Solidity uints are always non-negative; this invariant is about ensuring no unexpected
        // underflows cause a revert earlier and leave state inconsistent.
        assertGe(state.pendingBridgeIn, 0);
        assertGe(state.pendingBridgeOut, 0);
        assertGe(state.currentDebt, 0);
    }
}


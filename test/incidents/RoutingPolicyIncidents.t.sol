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
import {ICrossChainRoutingPolicy} from "../../contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol";

contract RoutingPolicyIncidentTests is Test {
    uint32 internal constant STRATEGY_ID = 1;
    uint32 internal constant STALE_STRATEGY_ID = 2;

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
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STALE_STRATEGY_ID,
                chainId: 1,
                agent: makeAddr("agent2"),
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

        // Use the vault itself as the routing policy source (staleness + max allocatable).
        allocator.setRoutingPolicy(ICrossChainRoutingPolicy(address(vault)));

        asset.mint(address(this), 1_000_000e6);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(200_000e6, address(this));
    }

    function testAllocationBlockedWhenVaultPolicyIsStale() public {
        // Make the vault policy stale via a different strategy. We intentionally create the
        // allocate operation against STRATEGY_ID so createOperation itself does not revert on the
        // target strategy before policy enforcement kicks in at Created -> Sent.
        registry.setStrategyState(
            STALE_STRATEGY_ID,
            CrossChainTypes.StrategyState({
                currentDebt: 1,
                lastReportedValue: 1,
                pendingBridgeIn: 0,
                pendingBridgeOut: 0,
                freeLiquidity: 0,
                unrealizedLossBuffer: 0,
                lastReportTimestamp: 0,
                lastAckTimestamp: 0,
                health: CrossChainTypes.StrategyHealth.Active
            })
        );

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        vm.expectRevert(StrategyAllocator.StrategyAllocator__DegradedModeNoAllocations.selector);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
    }

    function testAllocationBlockedWhenExceedingVaultMaxAllocatableAssets() public {
        vault.setMinimumResidualLiquidity(50e6);
        vault.setTargetLocalBufferAssets(80e6);

        uint256 maxAllocatable = vault.maxAllocatableAssets();
        assertGt(maxAllocatable, 0);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            maxAllocatable + 1,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__AllocationExceedsMaxAllocatable.selector,
                maxAllocatable + 1,
                maxAllocatable
            )
        );
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
    }
}

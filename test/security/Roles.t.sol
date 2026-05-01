// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";
import {ICrossChainRoutingPolicy} from "../../contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol";

contract RolesAccessTests is Test {
    uint32 internal constant STRATEGY_ID = 1;

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;

    address internal alice = makeAddr("alice");
    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");
    address internal reporter = makeAddr("reporter");

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
        settler.grantRole(settler.REPORTER_ROLE(), reporter);

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), bridge);

        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);

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
    }

    function testAllocatorCreateOperationRequiresAllocatorRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                allocator.ALLOCATOR_ROLE()
            )
        );
        vm.prank(alice);
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            1e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocatorSetOperationStatusRequiresKeeperRole() public {
        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            1e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                allocator.KEEPER_ROLE()
            )
        );
        vm.prank(alice);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
    }

    function testAllocatorRegisterBridgeDispatchRequiresBridgeRole() public {
        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            1e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        bytes memory payload = allocator.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            bytes("")
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                allocator.BRIDGE_ROLE()
            )
        );
        vm.prank(alice);
        allocator.registerBridgeDispatch(
            opId,
            1,
            makeAddr("remoteAgent"),
            keccak256("msg"),
            payload
        );
    }

    function testAllocatorSetRoutingPolicyRequiresGovernanceRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                allocator.GOVERNANCE_ROLE()
            )
        );
        vm.prank(alice);
        allocator.setRoutingPolicy(ICrossChainRoutingPolicy(address(vault)));
    }

    function testVaultSettersRequireGovernanceRole() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                vault.GOVERNANCE_ROLE()
            )
        );
        vault.setMinimumResidualLiquidity(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                vault.GOVERNANCE_ROLE()
            )
        );
        vault.setTargetLocalBufferAssets(1);
        vm.stopPrank();
    }

    function testVaultSyncOperationAccountingRequiresKeeperOrGovernance() public {
        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            1e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                vault.KEEPER_ROLE()
            )
        );
        vm.prank(alice);
        vault.syncOperationAccounting(opId);
    }

    function testVaultDispatchRemoteOperationRequiresKeeperOrGovernance() public {
        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            1e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                vault.KEEPER_ROLE()
            )
        );
        vm.prank(alice);
        vault.dispatchRemoteOperation(opId, makeAddr("bridgeAdapter"), bytes(""));
    }

    function testVaultReceiveRecallFundsRequiresBridgeKeeperOrGovernance() public {
        // Make sure we have enough token balance to satisfy the vault internal accounting check.
        asset.mint(address(vault), 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                vault.BRIDGE_ROLE()
            )
        );
        vm.prank(alice);
        vault.receiveRecallFunds(1e6);
    }

    function testSettlerSubmitReportRequiresReporterRole() public {
        CrossChainTypes.StrategyReport memory report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: 1,
            totalValue: 1,
            freeLiquidity: 1,
            totalDebt: 1,
            pnl: 0,
            reportTimestamp: uint64(block.timestamp),
            positionsHash: keccak256("positions")
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                settler.REPORTER_ROLE()
            )
        );
        vm.prank(alice);
        settler.submitReport(report);
    }

    function testQueueQueueWithdrawalRequiresKeeperOrVaultRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                queue.VAULT_ROLE()
            )
        );
        vm.prank(alice);
        queue.queueWithdrawal(alice, alice, 1, 1);
    }

    function testRegistryUpsertStrategyRequiresGovernanceRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                registry.GOVERNANCE_ROLE()
            )
        );
        vm.prank(alice);
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: 2,
                chainId: 1,
                agent: makeAddr("agent"),
                asset: makeAddr("asset"),
                debtLimit: 0,
                maxSlippageBps: 0,
                maxReportDelay: 0,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );
    }
}

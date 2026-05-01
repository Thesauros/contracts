// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";
import {ICrossChainRoutingPolicy} from "../../contracts/interfaces/crosschain/ICrossChainRoutingPolicy.sol";

contract MockRoutingPolicy is ICrossChainRoutingPolicy {
    bool internal _stale;
    uint256 internal _maxAllocatable;

    function setStale(bool v) external {
        _stale = v;
    }

    function setMaxAllocatable(uint256 v) external {
        _maxAllocatable = v;
    }

    function hasStaleStrategyReports() external view returns (bool) {
        return _stale;
    }

    function maxAllocatableAssets() external view returns (uint256) {
        return _maxAllocatable;
    }
}

contract StrategyAllocatorRiskTests is Test {
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    MockRoutingPolicy internal policy;

    address internal keeper = makeAddr("keeper");

    uint32 internal constant STRATEGY_ID = 1;

    function setUp() public {
        registry = new StrategyRegistry(address(this));
        allocator = new StrategyAllocator(address(this), registry);

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);

        policy = new MockRoutingPolicy();
        allocator.setRoutingPolicy(policy);

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: 1,
                agent: makeAddr("agent"),
                asset: makeAddr("asset"),
                debtLimit: 100e6,
                maxSlippageBps: 100,
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );
    }

    function testCreateOperationRejectsDebtLimitExceeded(uint96 currentDebt, uint96 assets) public {
        currentDebt = uint96(bound(currentDebt, 0, 100e6));
        assets = uint96(bound(assets, 1, 100e6));

        registry.setStrategyState(
            STRATEGY_ID,
            CrossChainTypes.StrategyState({
                currentDebt: currentDebt,
                lastReportedValue: currentDebt,
                pendingBridgeIn: 0,
                pendingBridgeOut: 0,
                freeLiquidity: currentDebt,
                unrealizedLossBuffer: 0,
                lastReportTimestamp: uint64(block.timestamp),
                lastAckTimestamp: 0,
                health: CrossChainTypes.StrategyHealth.Active
            })
        );

        uint256 requestedAfter = uint256(currentDebt) + uint256(assets);
        if (requestedAfter <= 100e6) {
            allocator.createOperation(
                STRATEGY_ID,
                CrossChainTypes.OperationType.Allocate,
                assets,
                0,
                uint64(block.timestamp + 1 days)
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StrategyAllocator.StrategyAllocator__DebtLimitExceeded.selector,
                    STRATEGY_ID,
                    requestedAfter,
                    uint256(100e6)
                )
            );
            allocator.createOperation(
                STRATEGY_ID,
                CrossChainTypes.OperationType.Allocate,
                assets,
                0,
                uint64(block.timestamp + 1 days)
            );
        }
    }

    function testAllocateSentIsBlockedWhenPolicyStale(uint96 assets) public {
        assets = uint96(bound(assets, 1, 10e6));

        policy.setStale(true);
        policy.setMaxAllocatable(type(uint256).max);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            assets,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        vm.expectRevert(StrategyAllocator.StrategyAllocator__DegradedModeNoAllocations.selector);
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
    }

    function testAllocateSentIsBlockedWhenExceedingMaxAllocatable(uint96 assets, uint96 maxAllocatable) public {
        assets = uint96(bound(assets, 1, 50e6));
        maxAllocatable = uint96(bound(maxAllocatable, 0, 50e6));

        policy.setStale(false);
        policy.setMaxAllocatable(maxAllocatable);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            assets,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        if (assets > maxAllocatable) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    StrategyAllocator.StrategyAllocator__AllocationExceedsMaxAllocatable.selector,
                    uint256(assets),
                    uint256(maxAllocatable)
                )
            );
        }
        allocator.setOperationStatus(opId, CrossChainTypes.OperationStatus.Sent);
    }
}

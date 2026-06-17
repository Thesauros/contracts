// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract StrategyAllocatorConfigIncidentTests is Test {
    uint32 internal constant STRATEGY_ID = 1;

    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;

    function setUp() public {
        registry = new StrategyRegistry(address(this));
        allocator = new StrategyAllocator(address(this), registry);
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
    }

    function testAllocateRejectedWhenDepositsDisabled() public {
        _upsertConfig(false, false, true, 100e6, 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__DepositsDisabled.selector,
                STRATEGY_ID
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testRecallRejectedWhenWithdrawalsDisabled() public {
        _upsertConfig(false, true, false, 100e6, 100);
        _setExposureAndDebt(50e6, uint64(block.timestamp));

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__WithdrawalsDisabled.selector,
                STRATEGY_ID
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocateRejectedWhenEmergencyExitOnly() public {
        _upsertConfig(true, true, true, 100e6, 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__EmergencyExitOnly.selector,
                STRATEGY_ID
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocateRejectedWhenStrategyPaused() public {
        _upsertConfig(false, true, true, 100e6, 100);

        registry.setStrategyState(
            STRATEGY_ID,
            CrossChainTypes.StrategyState({
                currentDebt: 0,
                lastReportedValue: 0,
                pendingBridgeIn: 0,
                pendingBridgeOut: 0,
                freeLiquidity: 0,
                unrealizedLossBuffer: 0,
                lastReportTimestamp: 0,
                lastAckTimestamp: 0,
                health: CrossChainTypes.StrategyHealth.Paused
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__StrategyNotActive.selector,
                STRATEGY_ID,
                CrossChainTypes.StrategyHealth.Paused
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocateRejectedWhenDebtLimitExceeded() public {
        _upsertConfig(false, true, true, 100e6, 100);
        _setExposureAndDebt(90e6, uint64(block.timestamp));

        uint256 requestedAfter = 90e6 + 20e6;
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
            20e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocateRejectedWhenMinOutTooLow() public {
        _upsertConfig(false, true, true, 1_000e6, 100);

        // assets=100e6, maxSlippageBps=100 => requiredMinOut=99e6
        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__MinAssetsOutTooLow.selector,
                STRATEGY_ID,
                uint256(98e6),
                uint256(99e6)
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            100e6,
            98e6,
            uint64(block.timestamp + 1 days)
        );
    }

    function testAllocateRejectedWhenReportStaleAndStrategyHasExposure() public {
        _upsertConfig(false, true, true, 1_000e6, 100);
        _setExposureAndDebt(1, 0); // exposure + no report timestamp

        vm.expectRevert(
            abi.encodeWithSelector(
                StrategyAllocator.StrategyAllocator__StrategyReportStale.selector,
                STRATEGY_ID
            )
        );
        allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            10e6,
            0,
            uint64(block.timestamp + 1 days)
        );
    }

    function _upsertConfig(
        bool emergencyExitOnly,
        bool depositsEnabled,
        bool withdrawalsEnabled,
        uint96 debtLimit,
        uint96 maxSlippageBps
    ) internal {
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: 1,
                agent: makeAddr("agent"),
                asset: makeAddr("asset"),
                debtLimit: debtLimit,
                maxSlippageBps: maxSlippageBps,
                maxReportDelay: 1 days,
                depositsEnabled: depositsEnabled,
                withdrawalsEnabled: withdrawalsEnabled,
                emergencyExitOnly: emergencyExitOnly,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );
    }

    function _setExposureAndDebt(uint256 debt, uint64 ts) internal {
        registry.setStrategyState(
            STRATEGY_ID,
            CrossChainTypes.StrategyState({
                currentDebt: debt,
                lastReportedValue: debt,
                pendingBridgeIn: 0,
                pendingBridgeOut: 0,
                freeLiquidity: debt,
                unrealizedLossBuffer: 0,
                lastReportTimestamp: ts,
                lastAckTimestamp: 0,
                health: CrossChainTypes.StrategyHealth.Active
            })
        );
    }
}

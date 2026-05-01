// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {LayerZeroBridgeAdapter} from "../../contracts/crosschain/LayerZeroBridgeAdapter.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract CrossChainVaultTests is Test {
    uint32 internal constant STRATEGY_ID = 1;
    uint32 internal constant REMOTE_CHAIN_ID = 40_161;
    uint256 internal constant DEPOSIT_AMOUNT = 100e6;
    uint256 internal constant REMOTE_VALUE = 50e6;
    uint48 internal constant MAX_REPORT_DELAY = 1 days;

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    ReportSettler internal settler;
    WithdrawalQueue internal queue;
    CrossChainVault internal vault;
    LayerZeroBridgeAdapter internal bridgeAdapter;

    address internal alice = makeAddr("alice");
    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");
    address internal reporter = makeAddr("reporter");
    address internal remoteAgent = makeAddr("remoteAgent");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        registry = new StrategyRegistry(address(this));
        allocator = new StrategyAllocator(address(this), registry);
        queue = new WithdrawalQueue(address(this));
        settler = new ReportSettler(address(this), registry);
        bridgeAdapter = new LayerZeroBridgeAdapter(address(this));
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
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), address(this));
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));
        settler.grantRole(settler.REPORTER_ROLE(), reporter);
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);
        bridgeAdapter.grantRole(bridgeAdapter.BRIDGE_ROLE(), address(vault));
        bridgeAdapter.setPeer(REMOTE_CHAIN_ID, bytes32(uint256(uint160(remoteAgent))));

        asset.mint(alice, 1_000_000e6);
    }

    function testDepositIncreasesHomeIdle() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(buckets.homeIdle, DEPOSIT_AMOUNT);
        assertEq(buckets.localBufferAssets, 0);
        assertEq(buckets.availableHomeLiquidity, DEPOSIT_AMOUNT);
        assertEq(buckets.totalManagedAssets, DEPOSIT_AMOUNT);
    }

    function testInstantWithdrawalCapacityHonorsMinimumResidualLiquidity() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

        vault.setMinimumResidualLiquidity(20e6);

        assertEq(vault.instantWithdrawalCapacity(), 80e6);
        assertEq(vault.maxWithdraw(alice), 80e6);
    }

    function testEntryChainIdMatchesDeploymentChain() public view {
        assertEq(vault.entryChainId(), block.chainid);
    }

    function testPositionViewTracksOneUserBalanceAcrossRemoteState() public {
        _configureStrategy();
        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(REMOTE_VALUE, REMOTE_VALUE, REMOTE_VALUE, uint64(block.timestamp));

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        CrossChainTypes.EntryPosition memory position = vault.positionView(alice);
        uint256 expectedAssets = vault.previewRedeem(DEPOSIT_AMOUNT);
        uint256 expectedMaxWithdraw = vault.maxWithdraw(alice);
        uint256 expectedMaxRedeem = vault.maxRedeem(alice);

        assertEq(position.shares, DEPOSIT_AMOUNT);
        assertEq(position.assetEquivalent, expectedAssets);
        assertEq(position.maxInstantWithdrawAssets, expectedMaxWithdraw);
        assertEq(position.maxInstantRedeemShares, expectedMaxRedeem);
    }

    function testNavBucketsExposeLocalBufferAsSubsetOfHomeIdle() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

        vault.setTargetLocalBufferAssets(25e6);

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(vault.targetLocalBufferAssets(), 25e6);
        assertEq(buckets.homeIdle, DEPOSIT_AMOUNT);
        assertEq(buckets.localBufferAssets, 25e6);
        assertEq(buckets.totalManagedAssets, DEPOSIT_AMOUNT);
    }

    function testLocalBufferAssetsAreCappedByHomeIdle() public {
        _depositAsAlice(10e6);

        vault.setTargetLocalBufferAssets(25e6);

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(buckets.homeIdle, 10e6);
        assertEq(buckets.localBufferAssets, 10e6);
        assertEq(buckets.totalManagedAssets, 10e6);
    }

    function testSettleStrategyReportUpdatesTotalAssets() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(REMOTE_VALUE, REMOTE_VALUE, REMOTE_VALUE, uint64(block.timestamp));

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        CrossChainTypes.StrategyState memory state = registry.getStrategyState(
            STRATEGY_ID
        );

        assertEq(state.lastReportedValue, REMOTE_VALUE);
        assertEq(state.freeLiquidity, REMOTE_VALUE);
        assertEq(state.currentDebt, REMOTE_VALUE);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT + REMOTE_VALUE);
    }

    function testNavBucketsIncludeStrategyTransitAndLossState() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        registry.setStrategyState(
            STRATEGY_ID,
            CrossChainTypes.StrategyState({
                currentDebt: REMOTE_VALUE,
                lastReportedValue: REMOTE_VALUE,
                pendingBridgeIn: 10e6,
                pendingBridgeOut: 5e6,
                freeLiquidity: 20e6,
                unrealizedLossBuffer: 3e6,
                lastReportTimestamp: uint64(block.timestamp),
                lastAckTimestamp: 0,
                health: CrossChainTypes.StrategyHealth.Active
            })
        );

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(buckets.homeIdle, DEPOSIT_AMOUNT);
        assertEq(buckets.settledStrategyValue, REMOTE_VALUE);
        assertEq(buckets.pendingBridgeIn, 10e6);
        assertEq(buckets.pendingBridgeOut, 5e6);
        assertEq(buckets.unrealizedLossBuffer, 3e6);
        assertEq(
            buckets.totalManagedAssets,
            DEPOSIT_AMOUNT + REMOTE_VALUE + 10e6 + 5e6 - 3e6
        );
    }

    function testDispatchRemoteOperationBridgesAllocateFromVault() public {
        _configureStrategy();
        _depositAsAlice(DEPOSIT_AMOUNT);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            25e6,
            0,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        bytes32 messageId = vault.dispatchRemoteOperation(
            opId,
            address(bridgeAdapter),
            bytes("dispatch")
        );

        CrossChainTypes.OperationDispatch memory dispatch = allocator
            .getOperationDispatch(opId);
        LayerZeroBridgeAdapter.BridgeMessage memory message = bridgeAdapter
            .getMessage(messageId);

        assertEq(dispatch.opId, opId);
        assertEq(dispatch.dstEid, REMOTE_CHAIN_ID);
        assertEq(dispatch.remoteAgent, remoteAgent);
        assertEq(dispatch.bridgeMessageId, messageId);
        assertEq(message.messageId, messageId);
        assertEq(message.amount, 25e6);
        assertEq(message.sender, address(vault));
        assertEq(asset.balanceOf(address(vault)), DEPOSIT_AMOUNT - 25e6);
        assertEq(asset.balanceOf(address(bridgeAdapter)), 25e6);
    }

    function testRequestAndClaimQueuedWithdrawalAfterRecallFunds() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(REMOTE_VALUE, REMOTE_VALUE, REMOTE_VALUE, uint64(block.timestamp));

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId, uint256 assetsPreview) =
            vault.requestWithdrawal(aliceShares, alice, alice);

        CrossChainTypes.WithdrawalRequest memory request = queue
            .getWithdrawalRequest(requestId);

        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Pending)
        );
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(address(vault)), request.shares);
        assertGt(assetsPreview, DEPOSIT_AMOUNT);

        asset.mint(address(vault), REMOTE_VALUE);

        vm.prank(bridge);
        vault.receiveRecallFunds(REMOTE_VALUE);

        vm.prank(keeper);
        vault.startWithdrawalFunding(requestId);

        vm.prank(keeper);
        vault.fundWithdrawal(requestId);

        vm.prank(alice);
        uint256 claimedAssets = vault.claimWithdrawal(requestId);

        request = queue.getWithdrawalRequest(requestId);

        assertEq(claimedAssets, assetsPreview);
        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Claimed)
        );
        assertGt(request.updatedAt, 0);
        assertGt(request.fundedAt, 0);
        assertGt(request.claimedAt, 0);
        assertEq(asset.balanceOf(alice), 1_000_000e6 - DEPOSIT_AMOUNT + claimedAssets);
        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT + REMOTE_VALUE - claimedAssets);
    }

    function testFundedWithdrawalReservesLiquidity() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(
            REMOTE_VALUE,
            REMOTE_VALUE,
            REMOTE_VALUE,
            uint64(block.timestamp)
        );

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId, uint256 assetsPreview) =
            vault.requestWithdrawal(aliceShares, alice, alice);

        asset.mint(address(vault), REMOTE_VALUE);

        vm.prank(bridge);
        vault.receiveRecallFunds(REMOTE_VALUE);

        vm.prank(keeper);
        vault.startWithdrawalFunding(requestId);

        vm.prank(keeper);
        vault.fundWithdrawal(requestId);

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(vault.fundedWithdrawalObligations(), assetsPreview);
        assertEq(
            vault.availableHomeLiquidity(),
            DEPOSIT_AMOUNT + REMOTE_VALUE - assetsPreview
        );
        assertEq(buckets.fundedWithdrawalObligations, assetsPreview);
        assertEq(
            buckets.availableHomeLiquidity,
            DEPOSIT_AMOUNT + REMOTE_VALUE - assetsPreview
        );
    }

    function testRequestWithdrawalUsesDelayedModeWhenResidualBufferWouldBeViolated()
        public
    {
        _depositAsAlice(DEPOSIT_AMOUNT);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId, uint256 assetsPreview) =
            vault.requestWithdrawal(aliceShares, alice, alice);

        CrossChainTypes.WithdrawalRequest memory request = queue
            .getWithdrawalRequest(requestId);

        assertEq(assetsPreview, DEPOSIT_AMOUNT);
        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Pending)
        );
        assertEq(vault.instantWithdrawalCapacity(), 80e6);
    }

    function testStartWithdrawalFundingMarksRequestProcessing() public {
        _depositAsAlice(DEPOSIT_AMOUNT);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(aliceShares, alice, alice);

        vm.prank(keeper);
        vault.startWithdrawalFunding(requestId);

        CrossChainTypes.WithdrawalRequest memory request = queue
            .getWithdrawalRequest(requestId);

        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Processing)
        );
        assertEq(request.fundedAt, 0);
        assertEq(request.claimedAt, 0);
        assertEq(vault.currentRedemptionSla(), 15 minutes);
    }

    function testFundWithdrawalRespectsMinimumResidualLiquidity() public {
        _depositAsAlice(DEPOSIT_AMOUNT);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(aliceShares, alice, alice);

        vm.prank(keeper);
        vault.startWithdrawalFunding(requestId);

        asset.mint(address(vault), 40e6);

        vm.prank(bridge);
        vault.receiveRecallFunds(40e6);

        vm.prank(keeper);
        vault.fundWithdrawal(requestId);

        CrossChainTypes.WithdrawalRequest memory request = queue
            .getWithdrawalRequest(requestId);

        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Funded)
        );
        assertGt(request.fundedAt, 0);
        assertEq(vault.availableHomeLiquidity(), 40e6);
        assertEq(vault.instantWithdrawalCapacity(), 20e6);
    }

    function testCancelWithdrawalReturnsSharesToOwner() public {
        _depositAsAlice(DEPOSIT_AMOUNT);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(aliceShares, alice, alice);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(address(vault)), aliceShares);

        vm.prank(alice);
        vault.cancelWithdrawal(requestId);

        CrossChainTypes.WithdrawalRequest memory request = queue
            .getWithdrawalRequest(requestId);

        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Cancelled)
        );
        assertEq(vault.balanceOf(alice), aliceShares);
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function testDegradedModeUsesConfiguredSla() public {
        vault.setRedemptionSla(15 minutes, 2 hours);
        vault.setDegradedRedemptionMode(true);

        assertEq(
            uint8(vault.currentRedemptionMode()),
            uint8(CrossChainTypes.RedemptionMode.Degraded)
        );
        assertEq(vault.currentRedemptionSla(), 2 hours);
    }

    function testDelayedFundingPauseBlocksFundingHooks() public {
        _depositAsAlice(DEPOSIT_AMOUNT);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(aliceShares, alice, alice);

        vault.setDelayedFundingPaused(true);

        vm.prank(keeper);
        vm.expectRevert(CrossChainVault.CrossChainVault__DelayedFundingPaused.selector);
        vault.startWithdrawalFunding(requestId);

        vm.prank(keeper);
        vm.expectRevert(CrossChainVault.CrossChainVault__DelayedFundingPaused.selector);
        vault.fundWithdrawal(requestId);
    }

    function testSyncOperationAccountingForAllocateLifecycle() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            40e6,
            396e5,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Sent
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(opId);

        CrossChainTypes.StrategyState memory state = registry.getStrategyState(
            STRATEGY_ID
        );

        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT - 40e6);
        assertEq(state.pendingBridgeOut, 40e6);
        assertEq(state.currentDebt, 0);

        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Received
        );
        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Executed
        );
        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Settled
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(opId);

        state = registry.getStrategyState(STRATEGY_ID);

        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT - 40e6);
        assertEq(state.pendingBridgeOut, 0);
        assertEq(state.currentDebt, 40e6);
    }

    function testSyncOperationAccountingForRecallLifecycle() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(
            REMOTE_VALUE,
            REMOTE_VALUE,
            REMOTE_VALUE,
            uint64(block.timestamp)
        );

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        bytes32 opId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            20e6,
            198e5,
            uint64(block.timestamp + 1 days)
        );

        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Sent
        );
        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Received
        );
        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Executed
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(opId);

        CrossChainTypes.StrategyState memory state = registry.getStrategyState(
            STRATEGY_ID
        );

        assertEq(state.currentDebt, REMOTE_VALUE - 20e6);
        assertEq(state.pendingBridgeIn, 20e6);

        asset.mint(address(vault), 20e6);

        vm.prank(bridge);
        vault.receiveRecallFunds(20e6);

        vm.prank(keeper);
        allocator.setOperationStatus(
            opId,
            CrossChainTypes.OperationStatus.Settled
        );

        vm.prank(keeper);
        vault.syncOperationAccounting(opId);

        state = registry.getStrategyState(STRATEGY_ID);

        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT + 20e6);
        assertEq(state.pendingBridgeIn, 0);
        assertEq(state.currentDebt, REMOTE_VALUE - 20e6);
    }

    function testMaxWithdrawReturnsZeroWhenReportIsStale() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        // Create a non-zero exposure without a report timestamp to trigger staleness checks.
        registry.setStrategyState(
            STRATEGY_ID,
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

        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);
    }

    function _configureStrategy() internal {
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: REMOTE_CHAIN_ID,
                agent: remoteAgent,
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 100,
                maxReportDelay: MAX_REPORT_DELAY,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Aave
            })
        );
    }

    function _submitReport(
        uint256 totalValue,
        uint256 freeLiquidity,
        uint256 totalDebt,
        uint64 reportTimestamp
    ) internal {
        vm.prank(reporter);
        settler.submitReport(
            CrossChainTypes.StrategyReport({
                strategyId: STRATEGY_ID,
                chainId: REMOTE_CHAIN_ID,
                totalValue: totalValue,
                freeLiquidity: freeLiquidity,
                totalDebt: totalDebt,
                pnl: 0,
                reportTimestamp: reportTimestamp,
                positionsHash: keccak256("positions")
            })
        );
    }

    function _depositAsAlice(uint256 assets) internal {
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        assertEq(asset.allowance(alice, address(vault)), type(uint256).max);

        vm.prank(alice);
        vault.deposit(assets, alice);
    }
}

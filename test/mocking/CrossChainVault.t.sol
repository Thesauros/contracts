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

    address internal alice = makeAddr("alice");
    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");
    address internal reporter = makeAddr("reporter");
    address internal remoteAgent = makeAddr("remoteAgent");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
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

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));
        settler.grantRole(settler.REPORTER_ROLE(), reporter);
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);

        asset.mint(alice, 1_000_000e6);
    }

    function testDepositIncreasesHomeIdle() public {
        _depositAsAlice(DEPOSIT_AMOUNT);

        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();

        assertEq(vault.homeIdle(), DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT);
        assertEq(vault.balanceOf(alice), DEPOSIT_AMOUNT);
        assertEq(buckets.homeIdle, DEPOSIT_AMOUNT);
        assertEq(buckets.availableHomeLiquidity, DEPOSIT_AMOUNT);
        assertEq(buckets.totalManagedAssets, DEPOSIT_AMOUNT);
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

    function testRequestAndClaimQueuedWithdrawalAfterRecallFunds() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

        _submitReport(REMOTE_VALUE, REMOTE_VALUE, REMOTE_VALUE, uint64(block.timestamp));

        vm.prank(keeper);
        vault.settleStrategyReport(STRATEGY_ID);

        vm.prank(alice);
        (uint256 requestId, uint256 assetsPreview) = vault.requestWithdrawal(
            vault.balanceOf(alice),
            alice,
            alice
        );

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
        vault.fundWithdrawal(requestId);

        vm.prank(alice);
        uint256 claimedAssets = vault.claimWithdrawal(requestId);

        request = queue.getWithdrawalRequest(requestId);

        assertEq(claimedAssets, assetsPreview);
        assertEq(
            uint8(request.status),
            uint8(CrossChainTypes.WithdrawalStatus.Claimed)
        );
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

        vm.prank(alice);
        (uint256 requestId, uint256 assetsPreview) = vault.requestWithdrawal(
            vault.balanceOf(alice),
            alice,
            alice
        );

        asset.mint(address(vault), REMOTE_VALUE);

        vm.prank(bridge);
        vault.receiveRecallFunds(REMOTE_VALUE);

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

    function testMaxWithdrawReturnsZeroWhenReportIsStale() public {
        _configureStrategy();

        _depositAsAlice(DEPOSIT_AMOUNT);

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

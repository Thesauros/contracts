// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";

contract RedemptionIncidentTests is Test {
    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal keeper = makeAddr("keeper");
    address internal bridge = makeAddr("bridge");

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
        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);

        asset.mint(alice, 1_000_000e6);
    }

    function testUnauthorizedCancelWithdrawalReverts() public {
        _depositAsAlice(100e6);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(shares, alice, alice);

        vm.prank(bob);
        vm.expectRevert(CrossChainVault.CrossChainVault__UnauthorizedCancellation.selector);
        vault.cancelWithdrawal(requestId);
    }

    function testUnauthorizedClaimWithdrawalReverts() public {
        _depositAsAlice(100e6);
        vault.setMinimumResidualLiquidity(20e6);

        uint256 shares = vault.balanceOf(alice);
        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(shares, alice, alice);

        // Add liquidity and fund.
        asset.mint(address(vault), 40e6);
        vm.prank(bridge);
        vault.receiveRecallFunds(40e6);

        vm.prank(keeper);
        vault.startWithdrawalFunding(requestId);
        vm.prank(keeper);
        vault.fundWithdrawal(requestId);

        vm.prank(bob);
        vm.expectRevert(CrossChainVault.CrossChainVault__UnauthorizedClaim.selector);
        vault.claimWithdrawal(requestId);
    }

    function _depositAsAlice(uint256 assets_) internal {
        vm.startPrank(alice);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(assets_, alice);
        vm.stopPrank();
    }
}

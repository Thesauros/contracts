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

contract CrossChainVaultHandler is Test {
    MockERC20 internal asset;
    CrossChainVault internal vault;

    address internal alice;
    address internal bob;

    uint256 internal lastRequestIdAlice;
    uint256 internal lastRequestIdBob;

    constructor(MockERC20 asset_, CrossChainVault vault_) {
        asset = asset_;
        vault = vault_;
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        asset.mint(alice, 1_000_000e6);
        asset.mint(bob, 1_000_000e6);
    }

    function depositAlice(uint96 assets) external {
        assets = uint96(bound(assets, 1e3, 50_000e6));
        vm.startPrank(alice);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(assets, alice);
        vm.stopPrank();
    }

    function depositBob(uint96 assets) external {
        assets = uint96(bound(assets, 1e3, 50_000e6));
        vm.startPrank(bob);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(assets, bob);
        vm.stopPrank();
    }

    function withdrawAlice(uint96 assets) external {
        uint256 maxAssets = vault.maxWithdraw(alice);
        if (maxAssets == 0) return;
        assets = uint96(bound(assets, 1, maxAssets));
        vm.prank(alice);
        vault.withdraw(assets, alice, alice);
    }

    function withdrawBob(uint96 assets) external {
        uint256 maxAssets = vault.maxWithdraw(bob);
        if (maxAssets == 0) return;
        assets = uint96(bound(assets, 1, maxAssets));
        vm.prank(bob);
        vault.withdraw(assets, bob, bob);
    }

    function requestWithdrawalAlice() external {
        uint256 shares = vault.balanceOf(alice);
        if (shares == 0) return;

        uint256 assetsPreview = vault.previewRedeem(shares);
        if (assetsPreview <= vault.instantWithdrawalCapacity()) return;

        vm.prank(alice);
        (uint256 requestId,) = vault.requestWithdrawal(shares, alice, alice);
        lastRequestIdAlice = requestId;
    }

    function requestWithdrawalBob() external {
        uint256 shares = vault.balanceOf(bob);
        if (shares == 0) return;

        uint256 assetsPreview = vault.previewRedeem(shares);
        if (assetsPreview <= vault.instantWithdrawalCapacity()) return;

        vm.prank(bob);
        (uint256 requestId,) = vault.requestWithdrawal(shares, bob, bob);
        lastRequestIdBob = requestId;
    }

    function startFundingAlice() external {
        if (lastRequestIdAlice == 0) return;
        // Keeper role is held by the invariant test contract, so call directly.
        try vault.startWithdrawalFunding(lastRequestIdAlice) {} catch {}
    }

    function startFundingBob() external {
        if (lastRequestIdBob == 0) return;
        try vault.startWithdrawalFunding(lastRequestIdBob) {} catch {}
    }

    function mintRecall(uint96 assets) external {
        assets = uint96(bound(assets, 1, 50_000e6));
        asset.mint(address(vault), assets);
        vault.receiveRecallFunds(assets);
    }

    function fundAlice() external {
        if (lastRequestIdAlice == 0) return;
        try vault.fundWithdrawal(lastRequestIdAlice) {} catch {}
    }

    function fundBob() external {
        if (lastRequestIdBob == 0) return;
        try vault.fundWithdrawal(lastRequestIdBob) {} catch {}
    }

    function claimAlice() external {
        if (lastRequestIdAlice == 0) return;
        vm.prank(alice);
        try vault.claimWithdrawal(lastRequestIdAlice) {} catch {}
    }

    function claimBob() external {
        if (lastRequestIdBob == 0) return;
        vm.prank(bob);
        try vault.claimWithdrawal(lastRequestIdBob) {} catch {}
    }
}

contract CrossChainVaultInvariantTests is StdInvariant, Test {
    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;
    CrossChainVaultHandler internal handler;

    address internal keeper = address(this);
    address internal bridge = address(this);

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

        handler = new CrossChainVaultHandler(asset, vault);
        // Let the handler actually exercise keeper/bridge paths (otherwise calls revert and get
        // swallowed by try/catch, or counted as invariant reverts).
        vault.grantRole(vault.KEEPER_ROLE(), address(handler));
        vault.grantRole(vault.BRIDGE_ROLE(), address(handler));
        targetContract(address(handler));
    }

    function invariant_fundedObligationsNeverExceedHomeIdle() public view {
        assertLe(vault.fundedWithdrawalObligations(), vault.homeIdle());
    }

    function invariant_totalAssetsMatchesNavBuckets() public view {
        CrossChainTypes.NavBuckets memory buckets = vault.navBuckets();
        assertEq(vault.totalAssets(), buckets.totalManagedAssets);
    }

    function invariant_assetBalanceCoversHomeIdle() public view {
        assertGe(asset.balanceOf(address(vault)), vault.homeIdle());
    }
}

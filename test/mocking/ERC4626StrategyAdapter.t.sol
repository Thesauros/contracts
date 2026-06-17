// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {ERC4626StrategyAdapter} from "../../contracts/crosschain/ERC4626StrategyAdapter.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockERC4626Vault} from "../../contracts/mocks/MockERC4626Vault.sol";

contract ERC4626StrategyAdapterTests is Test {
    ERC4626StrategyAdapter internal adapter;
    MockERC20 internal asset;
    MockERC4626Vault internal vault;

    address internal operator = makeAddr("operator");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        vault = new MockERC4626Vault(asset, "Mock Yield Vault", "myvUSDC");
        adapter = new ERC4626StrategyAdapter(address(vault));

        asset.mint(operator, 1_000_000e6);
    }

    function testDeployCapitalDepositsIntoVault() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 100e6);
        adapter.deployCapital(100e6, bytes(""));
        vm.stopPrank();

        assertEq(adapter.deployedPrincipal(), 100e6);
        assertEq(adapter.totalValue(), 100e6);
        assertEq(adapter.freeLiquidity(), 100e6);
        assertEq(asset.balanceOf(address(vault)), 100e6);
    }

    function testFreeCapitalWithdrawsRequestedLiquidity() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 100e6);
        adapter.deployCapital(100e6, bytes(""));
        uint256 assetsFreed = adapter.freeCapital(40e6, bytes(""));
        vm.stopPrank();

        assertEq(assetsFreed, 40e6);
        assertEq(adapter.deployedPrincipal(), 60e6);
        assertEq(adapter.totalValue(), 60e6);
        assertEq(asset.balanceOf(operator), 1_000_000e6 - 100e6 + 40e6);
    }

    function testHarvestWithdrawsPositivePnl() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 100e6);
        adapter.deployCapital(100e6, bytes(""));
        vm.stopPrank();

        vault.mintYield(9e6);

        vm.prank(operator);
        (int256 pnl, uint256 assetsOut) = adapter.harvest(bytes(""));

        assertLe(pnl, int256(9e6));
        assertGe(pnl, int256(9e6) - 1);
        assertApproxEqAbs(assetsOut, 9e6, 1);
        assertEq(adapter.deployedPrincipal(), 100e6);
        assertEq(adapter.totalValue(), 100e6);
        assertApproxEqAbs(
            asset.balanceOf(operator),
            1_000_000e6 - 100e6 + 9e6,
            1
        );
    }

    function testEmergencyExitWithdrawsEverything() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 150e6);
        adapter.deployCapital(150e6, bytes(""));
        vm.stopPrank();

        vault.mintYield(11e6);

        vm.prank(operator);
        uint256 assetsOut = adapter.emergencyExit(bytes(""));

        assertApproxEqAbs(assetsOut, 161e6, 1);
        assertEq(adapter.deployedPrincipal(), 0);
        assertEq(adapter.totalValue(), 0);
        assertApproxEqAbs(asset.balanceOf(operator), 1_000_000e6 + 11e6, 1);
    }
}

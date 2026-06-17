// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MorphoStrategyAdapter} from "../../contracts/crosschain/MorphoStrategyAdapter.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockMetaMorphoVault} from "../../contracts/mocks/MockMetaMorphoVault.sol";

contract MorphoStrategyAdapterTests is Test {
    MorphoStrategyAdapter internal adapter;
    MockERC20 internal asset;
    MockMetaMorphoVault internal metaMorpho;

    address internal operator = makeAddr("operator");

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        metaMorpho = new MockMetaMorphoVault(asset);
        adapter = new MorphoStrategyAdapter(address(metaMorpho));

        asset.mint(operator, 1_000_000e6);
    }

    function testDeployCapitalDepositsIntoMetaMorpho() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 100e6);
        adapter.deployCapital(100e6, bytes(""));
        vm.stopPrank();

        assertEq(adapter.deployedPrincipal(), 100e6);
        assertEq(adapter.totalValue(), 100e6);
        assertEq(adapter.freeLiquidity(), 100e6);
        assertEq(asset.balanceOf(address(metaMorpho)), 100e6);
    }

    function testFreeCapitalWithdrawsRequestedAssets() public {
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

        metaMorpho.mintYield(12e6);

        vm.prank(operator);
        (int256 pnl, uint256 assetsOut) = adapter.harvest(bytes(""));

        assertLe(pnl, int256(12e6));
        assertGe(pnl, int256(12e6) - 1);
        assertApproxEqAbs(assetsOut, 12e6, 1);
        assertEq(adapter.deployedPrincipal(), 100e6);
        assertEq(adapter.totalValue(), 100e6);
        assertApproxEqAbs(
            asset.balanceOf(operator),
            1_000_000e6 - 100e6 + 12e6,
            1
        );
    }

    function testEmergencyExitWithdrawsEverything() public {
        vm.startPrank(operator);
        asset.approve(address(adapter), 150e6);
        adapter.deployCapital(150e6, bytes(""));
        vm.stopPrank();

        metaMorpho.mintYield(10e6);

        vm.prank(operator);
        uint256 assetsOut = adapter.emergencyExit(bytes(""));

        assertApproxEqAbs(assetsOut, 160e6, 1);
        assertEq(adapter.deployedPrincipal(), 0);
        assertEq(adapter.totalValue(), 0);
        assertApproxEqAbs(asset.balanceOf(operator), 1_000_000e6 + 10e6, 1);
    }
}

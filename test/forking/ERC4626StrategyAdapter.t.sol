// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626StrategyAdapter} from "../../contracts/crosschain/ERC4626StrategyAdapter.sol";
import {StrategyAdapterForkingUtilities} from "../utils/StrategyAdapterForkingUtilities.sol";

contract ERC4626StrategyAdapterForkTests is StrategyAdapterForkingUtilities {
    ERC4626StrategyAdapter internal adapter;
    IERC20 internal asset;

    address internal operator = makeAddr("operator");

    function setUp() public {
        createArbitrumForkOrSkip();

        adapter = new ERC4626StrategyAdapter(MORPHO_HYPERITHM_VAULT_ADDRESS);
        asset = adapter.ASSET();
    }

    function testForkDeployAndFreeCapitalOnHyperithmVault() public {
        dealAndApprove(
            asset,
            operator,
            address(adapter),
            FORK_DEPOSIT_AMOUNT
        );

        vm.prank(operator);
        adapter.deployCapital(FORK_DEPOSIT_AMOUNT, bytes(""));

        assertApproxEqAbs(adapter.totalValue(), FORK_DEPOSIT_AMOUNT, 100);
        assertGt(adapter.freeLiquidity(), 0);

        vm.prank(operator);
        uint256 assetsFreed = adapter.freeCapital(
            FORK_PARTIAL_RECALL_AMOUNT,
            bytes("")
        );

        assertApproxEqAbs(assetsFreed, FORK_PARTIAL_RECALL_AMOUNT, 100);
        assertApproxEqAbs(
            adapter.totalValue(),
            FORK_DEPOSIT_AMOUNT - FORK_PARTIAL_RECALL_AMOUNT,
            100
        );
        assertEq(adapter.deployedPrincipal(), 60e6);
    }

    function testForkEmergencyExitOnHyperithmVault() public {
        dealAndApprove(
            asset,
            operator,
            address(adapter),
            FORK_DEPOSIT_AMOUNT
        );

        vm.prank(operator);
        adapter.deployCapital(FORK_DEPOSIT_AMOUNT, bytes(""));

        uint256 totalValueBefore = adapter.totalValue();

        vm.prank(operator);
        uint256 assetsOut = adapter.emergencyExit(bytes(""));

        assertApproxEqAbs(assetsOut, totalValueBefore, 100);
        assertEq(adapter.deployedPrincipal(), 0);
        assertLe(adapter.totalValue(), 100);
    }
}

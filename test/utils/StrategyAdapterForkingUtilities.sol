// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

contract StrategyAdapterForkingUtilities is Test {
    address public constant USDC_ADDRESS =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant MORPHO_GAUNTLET_CORE_VAULT_ADDRESS =
        0x7e97fa6893871A2751B5fE961978DCCb2c201E65;
    address public constant MORPHO_HYPERITHM_VAULT_ADDRESS =
        0x4B6F1C9E5d470b97181786b26da0d0945A7cf027;

    uint256 public constant FORK_DEPOSIT_AMOUNT = 100e6;
    uint256 public constant FORK_PARTIAL_RECALL_AMOUNT = 40e6;

    function createArbitrumForkOrSkip() internal {
        string memory arbitrumRpcUrl = vm.envOr(
            "ARBITRUM_RPC_URL",
            string("")
        );
        if (bytes(arbitrumRpcUrl).length == 0) {
            vm.skip(true, "ARBITRUM_RPC_URL is not set");
            return;
        }

        vm.createSelectFork(arbitrumRpcUrl);
    }

    function dealAndApprove(
        IERC20 asset,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        deal(address(asset), owner, amount);

        vm.prank(owner);
        asset.approve(spender, amount);
    }
}

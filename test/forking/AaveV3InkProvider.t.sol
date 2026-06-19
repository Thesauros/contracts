// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {Rebalancer} from "../../contracts/Rebalancer.sol";
import {Timelock} from "../../contracts/Timelock.sol";
import {AaveV3InkProvider} from "../../contracts/providers/AaveV3InkProvider.sol";
import {Test} from "forge-std/Test.sol";

/// @notice Fork tests for the Aave V3 (Tydro) integration on Ink (chainId 57073).
/// @dev Run with: forge test --match-contract AaveV3InkProviderTests --fork-url $INK_RPC_URL
contract AaveV3InkProviderTests is Test {
    // USD₮0 reserve listed on Tydro/Aave V3 on Ink.
    address public constant USDT0_ADDRESS =
        0x0200C29006150606B650577BBE7B6248F58470c1;

    uint256 public constant PRECISION_FACTOR = 1 ether;
    uint256 public constant WITHDRAW_FEE_PERCENT = 0.001 ether; // 0.1%

    uint256 public constant MIN_AMOUNT = 1e6;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    uint256 public constant TIMELOCK_DELAY = 30 minutes;

    address public alice = makeAddr("alice");
    address public initializer = makeAddr("initializer");
    address public treasury = makeAddr("treasury");

    IERC20 public usdt0 = IERC20(USDT0_ADDRESS);

    Rebalancer public vault;
    Timelock public timelock;
    AaveV3InkProvider public aaveV3Provider;

    function setUp() public {
        string memory INK_RPC_URL = vm.envString("INK_RPC_URL");
        vm.createSelectFork(INK_RPC_URL);

        vm.label(USDT0_ADDRESS, "USDT0");

        timelock = new Timelock(address(this), TIMELOCK_DELAY);
        aaveV3Provider = new AaveV3InkProvider();

        IProvider[] memory providers = new IProvider[](1);
        providers[0] = aaveV3Provider;

        vault = new Rebalancer(
            USDT0_ADDRESS,
            "Rebalance USDT0",
            "rUSDT0",
            providers,
            WITHDRAW_FEE_PERCENT,
            address(timelock),
            treasury
        );

        // initialize
        deal(USDT0_ADDRESS, initializer, MIN_AMOUNT);
        vm.startPrank(initializer);
        usdt0.approve(address(vault), MIN_AMOUNT);
        vault.setupVault(MIN_AMOUNT);
        vm.stopPrank();
    }

    function _deposit(uint256 amount, address from) internal {
        deal(USDT0_ADDRESS, from, amount);
        vm.startPrank(from);
        usdt0.approve(address(vault), amount);
        vault.deposit(amount, from);
        vm.stopPrank();
    }

    // =========================================
    // deposit
    // =========================================

    function testDeposit() public {
        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 assetsBefore = vault.convertToAssets(sharesBefore);

        _deposit(DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        uint256 shares = vault.balanceOf(alice);
        uint256 assets = vault.convertToAssets(shares);

        assertGe(assets - assetsBefore, DEPOSIT_AMOUNT);
    }

    // =========================================
    // withdraw
    // =========================================

    function testWithdraw() public {
        _deposit(DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        uint256 balanceBefore = usdt0.balanceOf(alice);
        uint256 maxWithdrawable = vault.maxWithdraw(alice);
        uint256 fee = (maxWithdrawable * WITHDRAW_FEE_PERCENT) /
            PRECISION_FACTOR;

        vm.prank(alice);
        vault.withdraw(maxWithdrawable, alice, alice);

        assertEq(
            usdt0.balanceOf(alice),
            balanceBefore + maxWithdrawable - fee
        );
    }

    // =========================================
    // getDepositBalance
    // =========================================

    function testDepositBalance() public {
        _deposit(DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        assertGe(vault.totalAssets(), DEPOSIT_AMOUNT + MIN_AMOUNT);
    }

    // =========================================
    // getDepositRate
    // =========================================

    function testDepositRate() public view {
        assertGt(aaveV3Provider.getDepositRate(vault), 0);
    }

    // =========================================
    // getIdentifier
    // =========================================

    function testIdentifier() public view {
        assertEq(aaveV3Provider.getIdentifier(), "Aave_V3_Provider");
    }
}

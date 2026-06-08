// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {Rebalancer} from "../../contracts/Rebalancer.sol";
import {Timelock} from "../../contracts/Timelock.sol";
import {AaveV3Provider} from "../../contracts/providers/AaveV3Provider.sol";
import {Test} from "forge-std/Test.sol";

contract AaveV3PlasmaProviderTests is Test {
    address public constant AAVE_V3_PLASMA_POOL_ADDRESSES_PROVIDER =
        0x061D8e131F26512348ee5FA42e2DF1bA9d6505E9;
    address public constant USDT0_ADDRESS =
        0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;

    uint256 public constant PRECISION_FACTOR = 1 ether;
    uint256 public constant WITHDRAW_FEE_PERCENT = 0.001 ether;
    uint256 public constant MIN_AMOUNT = 1e6;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    uint256 public constant TIMELOCK_DELAY = 30 minutes;

    address public alice = makeAddr("alice");
    address public initializer = makeAddr("initializer");
    address public treasury = makeAddr("treasury");

    IERC20 public usdt0;
    Rebalancer public vault;
    Timelock public timelock;
    AaveV3Provider public aaveV3Provider;

    constructor() {
        string memory plasmaRpcUrl = vm.envString("PLASMA_RPC_URL");
        vm.createSelectFork(plasmaRpcUrl);
    }

    function setUp() public {
        usdt0 = IERC20(USDT0_ADDRESS);
        vm.label(address(usdt0), "USDT0");

        timelock = new Timelock(address(this), TIMELOCK_DELAY);
        aaveV3Provider = new AaveV3Provider(
            AAVE_V3_PLASMA_POOL_ADDRESSES_PROVIDER
        );

        IProvider[] memory providers = new IProvider[](1);
        providers[0] = aaveV3Provider;

        vault = new Rebalancer(
            USDT0_ADDRESS,
            _vaultName(USDT0_ADDRESS),
            _vaultSymbol(USDT0_ADDRESS),
            providers,
            WITHDRAW_FEE_PERCENT,
            address(timelock),
            treasury
        );

        _initializeVault(vault, MIN_AMOUNT, initializer);
    }

    function testDeposit() public {
        uint256 mintedSharesBefore = vault.balanceOf(alice);
        uint256 assetBalanceBefore = vault.convertToAssets(mintedSharesBefore);

        _executeDeposit(vault, DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        uint256 mintedShares = vault.balanceOf(alice);
        uint256 assetBalance = vault.convertToAssets(mintedShares);

        assertGe(assetBalance - assetBalanceBefore, DEPOSIT_AMOUNT);
    }

    function testWithdraw() public {
        _executeDeposit(vault, DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        uint256 balanceBefore = IERC20(vault.asset()).balanceOf(alice);
        uint256 maxWithdrawable = vault.maxWithdraw(alice);
        uint256 fee = (maxWithdrawable * WITHDRAW_FEE_PERCENT) /
            PRECISION_FACTOR;

        vm.prank(alice);
        vault.withdraw(maxWithdrawable, alice, alice);

        uint256 balanceAfter = balanceBefore + maxWithdrawable - fee;
        assertEq(IERC20(vault.asset()).balanceOf(alice), balanceAfter);
    }

    function testDepositBalance() public {
        _executeDeposit(vault, DEPOSIT_AMOUNT, alice);

        vm.warp(block.timestamp + 10 seconds);
        vm.roll(block.number + 1);

        assertGe(vault.totalAssets(), DEPOSIT_AMOUNT + MIN_AMOUNT);
    }

    function testDepositRate() public view {
        assertGt(aaveV3Provider.getDepositRate(vault), 0);
    }

    function testIdentifier() public view {
        assertEq(aaveV3Provider.getIdentifier(), "Aave_V3_Provider");
    }

    function testPoolAddressesProvider() public view {
        assertEq(
            address(aaveV3Provider.getPoolAddressesProvider()),
            AAVE_V3_PLASMA_POOL_ADDRESSES_PROVIDER
        );
    }

    function _vaultName(address asset) internal view returns (string memory) {
        return string.concat("Rebalance ", IERC20Metadata(asset).name());
    }

    function _vaultSymbol(
        address asset
    ) internal view returns (string memory) {
        return string.concat("r", IERC20Metadata(asset).symbol());
    }

    function _initializeVault(
        IVault _vault,
        uint256 amount,
        address from
    ) internal {
        address asset = _vault.asset();

        deal(asset, from, amount);

        vm.startPrank(from);
        IERC20(asset).approve(address(_vault), amount);
        _vault.setupVault(amount);
        vm.stopPrank();
    }

    function _executeDeposit(
        IVault _vault,
        uint256 amount,
        address from
    ) internal {
        address asset = _vault.asset();

        deal(asset, from, amount);

        vm.startPrank(from);
        IERC20(asset).approve(address(_vault), amount);
        _vault.deposit(amount, from);
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {Vault} from "../../contracts/base/Vault.sol";
import {Rebalancer} from "../../contracts/Rebalancer.sol";
import {Timelock} from "../../contracts/Timelock.sol";
import {VaultManager} from "../../contracts/VaultManager.sol";
import {ProviderManager} from "../../contracts/providers/ProviderManager.sol";
import {CompoundV3Provider} from "../../contracts/providers/CompoundV3Provider.sol";
import {AaveV3Provider} from "../../contracts/providers/AaveV3Provider.sol";
import {Test} from "forge-std/Test.sol";

contract ForkingUtilities is Test {
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public initializer = makeAddr("initializer");
    address public treasury = makeAddr("treasury");

    Rebalancer public vault;
    Timelock public timelock;

    ProviderManager public providerManager;

    IERC20 public usdc;

    address public constant USDC_ADDRESS =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    address public constant COMET_USDC_ADDRESS =
        0xb125E6687d4313864e53df431d5425969c15Eb2F;
    address public constant MORPHO_RE7_VAULT_ADDRESS =
        0x12AFDeFb2237a5963e7BAb3e2D46ad0eee70406e;
    address public constant MORPHO_STEAKHOUSE_PRIME_VAULT_ADDRESS =
        0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2;
    address public constant MORPHO_STEAKHOUSE_HIGH_YIELD_VAULT_ADDRESS =
        0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F;
    address public constant MORPHO_GAUNTLET_CORE_VAULT_ADDRESS =
        0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12;

    uint256 public constant PRECISION_FACTOR = 1 ether;
    uint256 public constant WITHDRAW_FEE_PERCENT = 0.001 ether; // 0.1%

    uint256 public constant MIN_AMOUNT = 1e6;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    uint256 public constant TIMELOCK_DELAY = 30 minutes;

    constructor() {
        string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
        vm.createSelectFork(BASE_RPC_URL);

        usdc = IERC20(USDC_ADDRESS);
        vm.label(address(usdc), "USDC");

        providerManager = new ProviderManager(address(this));
        providerManager.setYieldToken(
            "Compound_V3_Provider",
            USDC_ADDRESS,
            COMET_USDC_ADDRESS
        );

        timelock = new Timelock(address(this), TIMELOCK_DELAY);
    }

    function deployVault(
        address _asset,
        IProvider[] memory _providers
    ) internal {
        string memory name = string.concat(
            "Rebalance ",
            IERC20Metadata(_asset).name()
        );
        string memory symbol = string.concat(
            "r",
            IERC20Metadata(_asset).symbol()
        );

        vault = new Rebalancer(
            _asset,
            name,
            symbol,
            _providers,
            WITHDRAW_FEE_PERCENT,
            address(timelock),
            treasury
        );
    }

    function initializeVault(
        IVault _vault,
        uint256 _amount,
        address _from
    ) internal {
        address asset = _vault.asset();

        deal(asset, _from, _amount);

        vm.startPrank(_from);
        IERC20(asset).approve(address(_vault), _amount);
        _vault.setupVault(_amount);
        vm.stopPrank();
    }

    function executeDeposit(
        IVault _vault,
        uint256 _amount,
        address _from
    ) internal {
        address asset = _vault.asset();

        deal(asset, _from, _amount);

        vm.startPrank(_from);
        IERC20(asset).approve(address(_vault), _amount);
        _vault.deposit(_amount, _from);
        vm.stopPrank();
    }

    function executeWithdraw(
        IVault _vault,
        uint256 _amount,
        address _from
    ) internal {
        vm.prank(_from);
        _vault.withdraw(_amount, _from, _from);
    }

    function executeRedeem(
        IVault _vault,
        uint256 _amount,
        address _from
    ) internal {
        vm.prank(_from);
        _vault.redeem(_amount, _from, _from);
    }
}

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
    IERC20 public usdt;

    address public constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address public constant COMET_USDC_ADDRESS =
        0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant COMET_USDT_ADDRESS =
        0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;

    address public constant MORPHO_STEAKHOUSE_VAULT_ADDRESS =
        0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB;
    address public constant MORPHO_GAUNTLET_CORE_VAULT_ADDRESS =
        0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458;
    address public constant MORPHO_GAUNTLET_PRIME_VAULT_ADDRESS =
        0xdd0f28e19C1780eb6396170735D45153D261490d;
    address public constant MORPHO_GAUNTLET_RWA_VAULT_ADDRESS =
        0xA8875aaeBc4f830524e35d57F9772FfAcbdD6C45;
    address public constant MORPHO_GAUNTLET_FRONTIER_VAULT_ADDRESS =
        0xc582F04d8a82795aa2Ff9c8bb4c1c889fe7b754e;
    address public constant MORPHO_OEV_BOOSTED_VAULT_ADDRESS =
        0x68Aea7b82Df6CcdF76235D46445Ed83f85F845A3;
    address public constant MORPHO_CLEARSTAR_HIGH_YIELD_VAULT_ADDRESS =
        0x9B5E92fd227876b4C07a8c02367E2CB23c639DfA;

    uint256 public constant PRECISION_FACTOR = 1 ether;
    uint256 public constant WITHDRAW_FEE_PERCENT = 0.001 ether; // 0.1%

    uint256 public constant MIN_AMOUNT = 1e6;
    uint256 public constant DEPOSIT_AMOUNT = 1000e6;
    uint256 public constant TIMELOCK_DELAY = 30 minutes;

    constructor() {
        string memory ETHEREUM_RPC_URL = vm.envString("ETHEREUM_RPC_URL");
        vm.createSelectFork(ETHEREUM_RPC_URL);

        usdt = IERC20(USDT_ADDRESS);
        vm.label(address(usdt), "USDT");

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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MorphoProvider} from "../../contracts/providers/MorphoProvider.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";
import {SecurityToken, SecurityCustody, SecurityProvider, SecurityVaultHarness} from "./LegacySecurity.t.sol";
import {Id, MarketParams, Market} from "morpho-blue/interfaces/IMorpho.sol";

interface MorphoTestVm { function expectRevert() external; }
contract RecoveryIrm {
    function borrowRateView(MarketParams memory, Market memory) external pure returns (uint256) { return 1e9; }
}
contract RecoveryMorpho {
    uint256 public real;
    uint256 public marketShares = 1_000e18;
    bool public rateEnabled;
    RecoveryIrm public immutable irm = new RecoveryIrm();
    function configure(uint256 real_, bool rate_) external { real = real_; rateEnabled = rate_; }
    function extSloads(bytes32[] calldata slots) external view returns (bytes32[] memory out) {
        out = new bytes32[](slots.length);
        for (uint256 i; i < slots.length; i++) out[i] = bytes32(marketShares);
    }
    function idToMarketParams(Id) external view returns (MarketParams memory) {
        return MarketParams(address(1), address(2), address(3), rateEnabled ? address(irm) : address(0), 0);
    }
    function market(Id) external view returns (Market memory) {
        return Market(uint128(real), uint128(marketShares), uint128(rateEnabled ? real / 2 : 0), 0, uint128(block.timestamp), 0);
    }
    function expectedReal() external view returns (uint256) {
        return marketShares * (real + 1) / (marketShares + 1e6);
    }
}
// Independent upstream V1/V1.1 accounting fixture. Book value is an input:
// V1 uses real supply; V1.1 may preserve persistent lostAssets in that value.
contract RecoveryMeta {
    RecoveryMorpho public immutable MORPHO;
    uint8 public immutable DECIMALS_OFFSET;
    uint256 public totalAssets;
    uint256 public totalSupply;
    uint256 public lastTotalAssets;
    uint96 public fee;
    mapping(address => uint256) public balanceOf;
    constructor(RecoveryMorpho morpho, uint8 offset) { MORPHO = morpho; DECIMALS_OFFSET = offset; }
    function configure(uint256 book, uint256 supply, uint256 last, uint96 fee_, address user, uint256 shares) external {
        totalAssets = book; totalSupply = supply; lastTotalAssets = last; fee = fee_; balanceOf[user] = shares;
    }
    function withdrawQueueLength() external pure returns (uint256) { return 1; }
    function withdrawQueue(uint256) external pure returns (Id) { return Id.wrap(bytes32(uint256(1))); }
    function convertToAssets(uint256 shares) external view returns (uint256) {
        uint256 interest = totalAssets > lastTotalAssets ? totalAssets - lastTotalAssets : 0;
        uint256 feeAssets = interest * fee / 1e18;
        uint256 virtualShares = 10 ** uint256(DECIMALS_OFFSET);
        uint256 pending = feeAssets * (totalSupply + virtualShares) / (totalAssets - feeAssets + 1);
        return shares * (totalAssets + 1) / (totalSupply + pending + virtualShares);
    }
}
contract MissingOffsetMeta {
    RecoveryMorpho public immutable MORPHO;
    constructor(RecoveryMorpho morpho) { MORPHO = morpho; }
    function balanceOf(address) external pure returns (uint256) { return 100; }
    function totalAssets() external pure returns (uint256) { return 100; }
    function withdrawQueueLength() external pure returns (uint256) { return 1; }
    function withdrawQueue(uint256) external pure returns (Id) { return Id.wrap(bytes32(uint256(1))); }
}
contract MorphoRecoverableRegressionTest {
    MorphoTestVm private constant vm = MorphoTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant USER = address(0xA11CE);
    RecoveryMorpho private morpho;
    RecoveryMeta private meta;
    MorphoProvider private provider;
    function setUp() public {
        morpho = new RecoveryMorpho(); morpho.configure(1_000e6, false);
        meta = new RecoveryMeta(morpho, 12);
        provider = new MorphoProvider(address(meta));
    }
    function expected(uint256 book, uint256 real, uint256 supply, uint256 last, uint256 fee, uint256 shares, uint256 offset)
        private pure returns (uint256) {
        uint256 feeAssets = book > last ? (book - last) * fee / 1e18 : 0;
        uint256 virtualShares = 10 ** offset;
        uint256 pending = feeAssets * (supply + virtualShares) / (book - feeAssets + 1);
        return shares * ((real < book ? real : book) + 1) / (supply + pending + virtualShares);
    }
    function test_SC006_V1QuoteMatchesPendingFeeAndVirtualShares() public {
        uint256 real = morpho.expectedReal();
        meta.configure(real, 1_000e18, 900e6, 0.2e18, USER, 500e18);
        require(provider.getDepositBalance(USER, IVault(address(0))) == meta.convertToAssets(500e18));
    }
    function test_SC006_V11PersistentLossUsesRecoverableValue() public {
        morpho.configure(600e6, false);
        meta.configure(1_000e6, 1_000e18, 1_000e6, 0.2e18, USER, 500e18);
        uint256 quote = provider.getDepositBalance(USER, IVault(address(0)));
        require(quote == expected(1_000e6, morpho.expectedReal(), 1_000e18, 1_000e6, 0.2e18, 500e18, 12));
        require(quote < 301e6 && quote < meta.convertToAssets(500e18));
    }
    function test_SC006_V11LossAndPendingFeeUseBookFeeButRealPayout() public {
        morpho.configure(600e6, false);
        meta.configure(1_000e6, 1_000e18, 900e6, 0.2e18, USER, 500e18);
        require(provider.getDepositBalance(USER, IVault(address(0))) ==
            expected(1_000e6, morpho.expectedReal(), 1_000e18, 900e6, 0.2e18, 500e18, 12));
    }
    function test_SC006_V1RealizedLossAndZeroOffset() public {
        RecoveryMeta noOffset = new RecoveryMeta(morpho, 0);
        MorphoProvider noOffsetProvider = new MorphoProvider(address(noOffset));
        morpho.configure(600e6, false);
        uint256 real = morpho.expectedReal();
        noOffset.configure(real, 1_000e6, 1_000e6, 0.2e18, USER, 500e6);
        require(noOffsetProvider.getDepositBalance(USER, IVault(address(0))) == noOffset.convertToAssets(500e6));
    }
    function test_SC006_ZeroAndDustPositions() public {
        meta.configure(1_000e6, 1_000e18, 900e6, 0.2e18, USER, 0);
        require(provider.getDepositBalance(USER, IVault(address(0))) == 0);
        meta.configure(1_000e6, 1_000e18, 900e6, 0.2e18, USER, 1);
        require(provider.getDepositBalance(USER, IVault(address(0))) == 0);
        morpho.configure(0, false);
        require(provider.getDepositBalance(USER, IVault(address(0))) == 0);
        require(provider.getDepositRate(IVault(address(0))) == 0);
    }
    function test_SC006_RateUsesSameRecoverableMarketBase() public {
        morpho.configure(600e6, true);
        meta.configure(1_000e6, 1_000e18, 1_000e6, 0.2e18, USER, 500e18);
        uint256 first = provider.getDepositRate(IVault(address(0)));
        meta.configure(2_000e6, 1_000e18, 2_000e6, 0.2e18, USER, 500e18);
        require(first > 0 && provider.getDepositRate(IVault(address(0))) == first);
    }
    function test_SC006_UnsupportedOffsetFailsClosed() public {
        MissingOffsetMeta missing = new MissingOffsetMeta(morpho);
        MorphoProvider incompatible = new MorphoProvider(address(missing));
        vm.expectRevert(); incompatible.getDepositBalance(USER, IVault(address(0)));
    }
    function test_SC006_HealthyLiquidityCannotPayBookLossToEarlyRedeemer() public {
        SecurityToken token = new SecurityToken();
        SecurityCustody healthy = new SecurityCustody(token);
        IProvider[] memory providers = new IProvider[](2);
        providers[0] = new SecurityProvider(healthy);
        providers[1] = provider;
        SecurityVaultHarness vault = new SecurityVaultHarness(token, providers);
        token.mint(address(this), 1_100e6);
        token.approve(address(vault), type(uint256).max);
        vault.setupVault(100e6); vault.deposit(1_000e6, address(this));
        morpho.configure(600e6, false);
        meta.configure(1_000e6, 1_000e18, 1_000e6, 0, address(vault), 500e18);
        uint256 recoverable = provider.getDepositBalance(address(vault), IVault(address(vault)));
        require(vault.totalAssets() == 1_100e6 + recoverable);
        uint256 expectedPayout = (1_100e6 + recoverable) * 500e6 / 1_100e6;
        uint256 paid = vault.redeem(500e6, address(this), address(this));
        require(paid == expectedPayout && token.balanceOf(address(this)) == paid);
        require(vault.totalAssets() == 1_100e6 + recoverable - paid);
    }
}

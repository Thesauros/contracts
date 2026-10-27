// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Rebalancer} from "../../contracts/Rebalancer.sol";
import {Vault} from "../../contracts/base/Vault.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {ProviderManager} from "../../contracts/providers/ProviderManager.sol";

interface SecurityVm {
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function prank(address) external;
}
contract SecurityToken is ERC20 {
    constructor() ERC20("Security fixture", "FIX") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}
contract SecurityCustody {
    SecurityToken public immutable token;
    mapping(address => uint256) public positions;
    uint256 public mode;
    bool public brokenView;
    constructor(SecurityToken token_) { token = token_; }
    function configure(uint256 mode_, bool broken_) external { mode = mode_; brokenView = broken_; }
    function deposit(address vault, uint256 amount) external {
        require(msg.sender == vault);
        require(token.transferFrom(vault, address(this), amount));
        positions[vault] += amount;
    }
    function withdraw(address vault, uint256 amount) external {
        require(msg.sender == vault);
        if (mode == 1) revert("paused fixture");
        if (mode == 2) amount /= 2;
        if (mode == 3) return;
        positions[vault] -= amount;
        require(token.transfer(vault, amount));
    }
    function yieldTo(address vault, uint256 amount) external {
        token.mint(address(this), amount);
        positions[vault] += amount;
    }
}
contract SecurityProvider is IProvider {
    SecurityCustody public immutable custody;
    constructor(SecurityCustody custody_) { custody = custody_; }
    function getIdentifier() external pure returns (string memory) { return "security"; }
    function getSource(address, address, address) external view virtual returns (address) { return address(custody); }
    function deposit(uint256 amount, IVault vault) external returns (bool) {
        custody.deposit(address(vault), amount); return true;
    }
    function withdraw(uint256 amount, IVault vault) external returns (bool) {
        custody.withdraw(address(vault), amount); return true;
    }
    function getDepositBalance(address user, IVault) external view returns (uint256) {
        require(!custody.brokenView(), "unknown NAV");
        return custody.positions(user);
    }
    function getDepositRate(IVault) external pure returns (uint256) { return 0; }
}
contract SecurityReceiptCustody is SecurityCustody {
    bool public residual = true;
    constructor(SecurityToken token_) SecurityCustody(token_) {}
    function clearResidual() external { residual = false; }
    function balanceOf(address) external view returns (uint256) { return residual ? 1 : 0; }
}
contract SecurityMutableProvider is SecurityProvider {
    address public source;
    constructor(SecurityCustody custody_) SecurityProvider(custody_) { source = address(custody_); }
    function retarget(address next) external { source = next; }
    function getSource(address, address, address) external view override returns (address) { return source; }
}
contract SecurityVaultHarness is Rebalancer {
    constructor(SecurityToken token, IProvider[] memory providers)
        Rebalancer(address(token), "Security vault", "SV", providers, 0, msg.sender, msg.sender) {}
    // Test arrangement uses the actual production provider delegation.
    function arrange(uint256 amount, IProvider from, IProvider to) external {
        _delegateActionToProvider(amount, "withdraw", from);
        _delegateActionToProvider(amount, "deposit", to);
    }
}
contract LegacySecurityRegressionTest {
    SecurityVm private constant vm = SecurityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    SecurityToken private token;
    SecurityCustody private a;
    SecurityCustody private b;
    SecurityProvider private pa;
    SecurityProvider private pb;
    SecurityVaultHarness private vault;

    function setUp() public {
        token = new SecurityToken();
        a = new SecurityCustody(token); b = new SecurityCustody(token);
        pa = new SecurityProvider(a); pb = new SecurityProvider(b);
        vault = new SecurityVaultHarness(token, list(pa, pb));
        token.mint(address(this), 2_000e6);
        token.approve(address(vault), type(uint256).max);
        vault.setupVault(100e6);
        vault.deposit(1_000e6, address(this));
    }
    function list(IProvider x, IProvider y) private pure returns (IProvider[] memory ps) {
        ps = new IProvider[](2); ps[0] = x; ps[1] = y;
    }
    function one(IProvider x) private pure returns (IProvider[] memory ps) {
        ps = new IProvider[](1); ps[0] = x;
    }
    function split() private { vault.arrange(600e6, pa, pb); }
    function test_SC005_emptyActiveUsesLaterLiquidity() public {
        vault.arrange(1_100e6, pa, pb);
        uint256 before = token.balanceOf(address(this));
        vault.withdraw(200e6, address(this), address(this));
        require(token.balanceOf(address(this)) == before + 200e6);
    }
    function test_SC005_revertingFirstActionIsIsolated() public {
        split(); a.configure(1, false);
        uint256 before = token.balanceOf(address(this));
        vault.withdraw(200e6, address(this), address(this));
        require(token.balanceOf(address(this)) == before + 200e6);
        require(a.positions(address(vault)) == 500e6);
    }
    function test_SC005_unknownFundedNavFailsWithoutBurn() public {
        split(); a.configure(0, true);
        uint256 shares = vault.balanceOf(address(this));
        vm.expectRevert();
        vault.redeem(100e6, address(this), address(this));
        require(vault.balanceOf(address(this)) == shares);
        require(b.positions(address(vault)) == 600e6);
    }
    function test_SC005_insufficientLiquidityRollsBackAllProvidersAndShares() public {
        split(); a.configure(1, false);
        uint256 shares = vault.balanceOf(address(this));
        vm.expectRevert(Vault.Vault__InsufficientLiquidity.selector);
        vault.withdraw(700e6, address(this), address(this));
        require(vault.balanceOf(address(this)) == shares);
        require(b.positions(address(vault)) == 600e6);
    }
    function test_SC005_partialReceiptUsesMeasuredRemainder() public {
        split(); a.configure(2, false);
        vault.withdraw(200e6, address(this), address(this));
        require(a.positions(address(vault)) == 400e6);
        require(b.positions(address(vault)) == 500e6);
        require(vault.totalAssets() == 900e6);
    }
    function test_SC005_successWithoutReceiptCannotSatisfyExit() public {
        split(); a.configure(3, false);
        vault.withdraw(200e6, address(this), address(this));
        require(a.positions(address(vault)) == 500e6);
        require(b.positions(address(vault)) == 400e6);
    }
    function test_SC005_allFalseReceiptsRevertWithoutBurn() public {
        split(); a.configure(3, false); b.configure(3, false);
        uint256 shares = vault.balanceOf(address(this));
        vm.expectRevert(Vault.Vault__InsufficientLiquidity.selector);
        vault.withdraw(200e6, address(this), address(this));
        require(vault.balanceOf(address(this)) == shares);
    }
    function test_SC005_idleUnderlyingIsCountedAndUsable() public {
        token.mint(address(vault), 110e6);
        require(vault.totalAssets() == 1_210e6);
        a.configure(1, false); b.configure(1, false);
        vault.withdraw(100e6, address(this), address(this));
        require(token.balanceOf(address(vault)) == 10e6);
    }
    function test_SC007_duplicateAdapterAndEconomicAliasRejectAtConstruction() public {
        vm.expectRevert(Vault.Vault__DuplicateProviderSource.selector);
        new SecurityVaultHarness(token, list(pa, pa));
        SecurityProvider aliasProvider = new SecurityProvider(a);
        vm.expectRevert(Vault.Vault__DuplicateProviderSource.selector);
        new SecurityVaultHarness(token, list(pa, aliasProvider));
    }
    function test_SC007_duplicateAliasAndEmptyListRejectAtUpdate() public {
        SecurityProvider aliasProvider = new SecurityProvider(a);
        vm.expectRevert(Vault.Vault__DuplicateProviderSource.selector);
        vault.setProviders(list(pa, aliasProvider));
        vm.expectRevert(Vault.Vault__InvalidInput.selector);
        vault.setProviders(new IProvider[](0));
        require(vault.totalAssets() == 1_100e6);
    }
    function test_SC007_fundedRemovalRejected() public {
        vm.expectRevert(Vault.Vault__FundedProvider.selector);
        vault.setProviders(one(pb));
        require(token.allowance(address(vault), address(a)) == type(uint256).max);
    }
    function test_SC007_zeroMigrationRevokesRecordedApprovalAndUpdatesActive() public {
        vault.arrange(1_100e6, pa, pb);
        vault.setProviders(one(pb));
        require(token.allowance(address(vault), address(a)) == 0);
        require(token.allowance(address(vault), address(b)) == type(uint256).max);
        require(address(vault.activeProvider()) == address(pb));
        require(vault.totalAssets() == 1_100e6);
        vault.withdraw(100e6, address(this), address(this));
    }
    function test_SC007_failedRemovalViewIsNotAnEmptyPosition() public {
        a.configure(0, true);
        vm.expectRevert();
        vault.setProviders(one(pb));
        require(token.allowance(address(vault), address(a)) == type(uint256).max);
    }
    function test_SC007_zeroNavReceiptClaimMustBeMigratedBeforeRemoval() public {
        SecurityReceiptCustody custody = new SecurityReceiptCustody(token);
        SecurityProvider receiptProvider = new SecurityProvider(custody);
        SecurityVaultHarness other = new SecurityVaultHarness(token, list(receiptProvider, pb));
        require(other.totalAssets() == 0);
        vm.expectRevert(Vault.Vault__FundedProvider.selector);
        other.setProviders(one(pb));
        custody.clearResidual();
        other.setProviders(one(pb));
        require(token.allowance(address(other), address(custody)) == 0);
    }
    function test_SC008_sourceRetargetCannotHideOldPosition() public {
        SecurityMutableProvider mutableProvider = new SecurityMutableProvider(a);
        SecurityVaultHarness other = new SecurityVaultHarness(token, one(mutableProvider));
        token.approve(address(other), type(uint256).max);
        other.setupVault(1e6);
        mutableProvider.retarget(address(b));
        vm.expectRevert(Vault.Vault__ProviderSourceChanged.selector);
        other.totalAssets();
        vm.expectRevert(Vault.Vault__ProviderSourceChanged.selector);
        other.setProviders(one(mutableProvider));
        require(token.allowance(address(other), address(a)) == type(uint256).max);
        require(token.allowance(address(other), address(b)) == 0);
    }
    function test_SC008_registryInitialBindIdempotentAndNoRetarget() public {
        ProviderManager manager = new ProviderManager(address(this));
        manager.setYieldToken("source", address(token), address(a));
        manager.setYieldToken("source", address(token), address(a));
        vm.expectRevert(ProviderManager.ProviderManager__ImmutableSource.selector);
        manager.setYieldToken("source", address(token), address(b));
        require(manager.getYieldToken("source", address(token)) == address(a));
        manager.setMarket("market", address(token), address(a), address(b));
        manager.setMarket("market", address(token), address(a), address(b));
        vm.expectRevert(ProviderManager.ProviderManager__ImmutableSource.selector);
        manager.setMarket("market", address(token), address(a), address(pa));
        vm.expectRevert(ProviderManager.ProviderManager__AddressZero.selector);
        manager.setYieldToken("source", address(token), address(0));
    }
    function test_SC009_oversizedWithdrawAndRedeemReject() public {
        uint256 tooManyAssets = vault.maxWithdraw(address(this)) + 1;
        uint256 tooManyShares = vault.balanceOf(address(this)) + 1;
        vm.expectRevert(Vault.Vault__ExceededOwnerLimit.selector);
        vault.withdraw(tooManyAssets, address(this), address(this));
        vm.expectRevert(Vault.Vault__ExceededOwnerLimit.selector);
        vault.redeem(tooManyShares, address(this), address(this));
    }
    function test_SC009_dustCannotPayWithoutUpwardRoundedAllowance() public {
        SecurityVaultHarness dust = new SecurityVaultHarness(token, one(pa));
        token.approve(address(dust), type(uint256).max);
        dust.setMinAmount(1); dust.setupVault(1); dust.deposit(1, address(this));
        a.yieldTo(address(dust), 1);
        require(dust.totalSupply() == 2 && dust.totalAssets() == 3);
        vm.expectRevert(Vault.Vault__ExceededOwnerLimit.selector);
        dust.withdraw(3, address(this), address(this));
        vm.expectRevert();
        vm.prank(address(0xBEEF));
        dust.withdraw(1, address(0xBEEF), address(this));
        require(dust.balanceOf(address(this)) == 1);
        require(dust.withdraw(1, address(this), address(this)) == 1);
    }
    function testFuzz_SC009_positiveWithdrawAlwaysChargesCeil(uint64 earned, uint64 requested) public {
        uint256 yieldAmount = uint256(earned) % 1_000_000e6;
        a.yieldTo(address(vault), yieldAmount);
        uint256 assets = uint256(requested) % vault.maxWithdraw(address(this)) + 1;
        uint256 supply = vault.totalSupply();
        uint256 nav = vault.totalAssets();
        uint256 expected = (assets * supply + nav - 1) / nav;
        uint256 before = vault.balanceOf(address(this));
        uint256 charged = vault.withdraw(assets, address(this), address(this));
        require(charged == expected && charged > 0);
        require(vault.balanceOf(address(this)) == before - expected);
    }
}

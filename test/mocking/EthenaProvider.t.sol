// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {EthenaProvider} from "../../contracts/providers/EthenaProvider.sol";
import {IEthenaStaking} from "../../contracts/interfaces/ethena/IEthenaStaking.sol";
import {IUSDe} from "../../contracts/interfaces/ethena/IUSDe.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockEthenaStaking} from "./mocks/MockEthenaStaking.sol";
import {MockUSDe} from "./mocks/MockUSDe.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";

contract EthenaProviderTest is Test {
    EthenaProvider public ethenaProvider;
    MockEthenaStaking public mockEthenaStaking;
    MockUSDe public mockUSDe;
    MockERC20 public mockCollateral;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant DEPOSIT_AMOUNT = 100e6;   // 100 USDT
    uint256 public constant TARGET_APY = 9e25;        // 9% in ray

    function setUp() public {
        // Deploy mock contracts
        mockCollateral = new MockERC20("Mock USDT", "USDT", 6);
        mockUSDe = new MockUSDe("Mock USDe", "USDe", 6);
        mockEthenaStaking = new MockEthenaStaking(address(mockUSDe));

        // Deploy EthenaProvider
        ethenaProvider = new EthenaProvider(
            address(mockEthenaStaking),
            address(mockUSDe),
            address(mockCollateral)
        );

        // Setup initial balances
        mockCollateral.mint(alice, INITIAL_BALANCE);
        mockCollateral.mint(bob, INITIAL_BALANCE);
        mockUSDe.mint(address(ethenaProvider), INITIAL_BALANCE);

        // Label addresses for better debugging
        vm.label(address(ethenaProvider), "EthenaProvider");
        vm.label(address(mockEthenaStaking), "MockEthenaStaking");
        vm.label(address(mockUSDe), "MockUSDe");
        vm.label(address(mockCollateral), "MockCollateral");
    }

    function test_Constructor() public {
        assertEq(address(ethenaProvider.ethenaStaking()), address(mockEthenaStaking));
        assertEq(address(ethenaProvider.usdeToken()), address(mockUSDe));
        assertEq(address(ethenaProvider.collateralToken()), address(mockCollateral));
        assertEq(ethenaProvider.getIdentifier(), "Ethena_Provider");
    }

    function test_Constructor_AddressZero() public {
        vm.expectRevert(EthenaProvider.EthenaProvider__AddressZero.selector);
        new EthenaProvider(address(0), address(mockUSDe), address(mockCollateral));

        vm.expectRevert(EthenaProvider.EthenaProvider__AddressZero.selector);
        new EthenaProvider(address(mockEthenaStaking), address(0), address(mockCollateral));

        vm.expectRevert(EthenaProvider.EthenaProvider__AddressZero.selector);
        new EthenaProvider(address(mockEthenaStaking), address(mockUSDe), address(0));
    }

    function test_GetDepositRate() public view {
        uint256 rate = ethenaProvider.getDepositRate(IVault(address(0)));
        assertEq(rate, TARGET_APY);
    }

    function test_GetSource() public view{
        address source = ethenaProvider.getSource(address(0), address(0), address(0));
        assertEq(source, address(mockEthenaStaking));
    }

    function test_GetCurrentAPY() public view{
        uint256 apy = ethenaProvider.getCurrentAPY();
        assertEq(apy, 900); // 9% in basis points
    }

    function test_GetTotalStaked() public view{
        uint256 totalStaked = ethenaProvider.getTotalStaked();
        assertEq(totalStaked, 0); // Initially 0
    }

    function test_GetPendingRewards() public view{
        uint256 pendingRewards = ethenaProvider.getPendingRewards(alice);
        assertEq(pendingRewards, 0); // Initially 0
    }

    function test_ClaimRewards() public {
        // This should not revert
        ethenaProvider.claimRewards();
    }

    function test_GetDepositBalance() public view{
        uint256 balance = ethenaProvider.getDepositBalance(alice, IVault(address(0)));
        assertEq(balance, 0); // Initially 0
    }
}


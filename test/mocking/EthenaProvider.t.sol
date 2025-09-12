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
import {IProviderManager} from "../../contracts/interfaces/IProviderManager.sol";

// Mock Vault for testing
contract MockVault {
    address public asset;
    
    constructor(address _asset) {
        asset = _asset;
    }
}

// Mock ProviderManager for testing
contract MockProviderManager is IProviderManager {
    mapping(string => mapping(address => address)) private yieldTokens;
    
    function setYieldToken(string memory identifier, address asset, address yieldToken) external {
        yieldTokens[identifier][asset] = yieldToken;
    }
    
    function getYieldToken(string memory identifier, address asset) external view override returns (address) {
        return yieldTokens[identifier][asset];
    }
    
    function getMarket(string memory, address, address) external pure override returns (address) {
        return address(0);
    }
    
    function setMarket(string memory, address, address, address) external pure override {}
}

contract EthenaProviderTest is Test {
    EthenaProvider public ethenaProvider;
    MockEthenaStaking public mockEthenaStaking;
    MockUSDe public mockUSDe;
    MockERC20 public mockCollateral;
    MockVault public mockVault;
    MockProviderManager public mockProviderManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_BALANCE = 1000e6; // 1000 USDT
    uint256 public constant DEPOSIT_AMOUNT = 100e6;   // 100 USDT
    uint256 public constant TARGET_APY = 900;         // 9% in basis points (as returned by mock)

    function setUp() public {
        // Deploy mock contracts
        mockCollateral = new MockERC20("Mock USDT", "USDT", 6);
        mockUSDe = new MockUSDe("Mock USDe", "USDe", 6);
        mockEthenaStaking = new MockEthenaStaking(address(mockUSDe));
        mockVault = new MockVault(address(mockCollateral));
        mockProviderManager = new MockProviderManager();

        // Deploy EthenaProvider
        ethenaProvider = new EthenaProvider(address(mockProviderManager));

        // Setup ProviderManager mappings
        mockProviderManager.setYieldToken("Ethena_Provider", address(mockCollateral), address(mockEthenaStaking));

        // Setup initial balances
        mockCollateral.mint(alice, INITIAL_BALANCE);
        mockCollateral.mint(bob, INITIAL_BALANCE);
        mockUSDe.mint(address(ethenaProvider), INITIAL_BALANCE);

        // Label addresses for better debugging
        vm.label(address(ethenaProvider), "EthenaProvider");
        vm.label(address(mockEthenaStaking), "MockEthenaStaking");
        vm.label(address(mockUSDe), "MockUSDe");
        vm.label(address(mockCollateral), "MockCollateral");
        vm.label(address(mockVault), "MockVault");
        vm.label(address(mockProviderManager), "MockProviderManager");
    }

    function test_Constructor() public view {
        assertEq(ethenaProvider.getIdentifier(), "Ethena_Provider");
    }

    function test_Constructor_AddressZero() public {
        vm.expectRevert(EthenaProvider.EthenaProvider__AddressZero.selector);
        new EthenaProvider(address(0));
    }

    function test_GetDepositRate() public view {
        uint256 rate = ethenaProvider.getDepositRate(IVault(address(mockVault)));
        assertEq(rate, TARGET_APY);
    }

    function test_GetSource() public view{
        address source = ethenaProvider.getSource(address(mockCollateral), address(0), address(0));
        assertEq(source, address(mockEthenaStaking));
    }


    function test_GetTotalStaked() public view{
        uint256 totalStaked = ethenaProvider.getTotalStaked(IVault(address(mockVault)));
        assertEq(totalStaked, 0); // Initially 0
    }

    function test_GetPendingRewards() public view{
        uint256 pendingRewards = ethenaProvider.getPendingRewards(alice, IVault(address(mockVault)));
        assertEq(pendingRewards, 0); // Initially 0
    }

    function test_ClaimRewards() public {
        // This should not revert
        ethenaProvider.claimRewards(IVault(address(mockVault)));
    }

    function test_GetDepositBalance() public view{
        uint256 balance = ethenaProvider.getDepositBalance(alice, IVault(address(mockVault)));
        assertEq(balance, 0); // Initially 0
    }

    function test_InvalidAsset_Reverts() public {
        // Create a vault with wrong asset (not registered in ProviderManager)
        MockERC20 wrongAsset = new MockERC20("Wrong Asset", "WA", 18);
        MockVault wrongVault = new MockVault(address(wrongAsset));

        // Test getDepositBalance with wrong asset
        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositBalance(alice, IVault(address(wrongVault)));

        // Test getDepositRate with wrong asset
        vm.expectRevert("EthenaProvider: Unsupported asset");
        ethenaProvider.getDepositRate(IVault(address(wrongVault)));
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessManager} from "../../contracts/access/AccessManager.sol";
import {RebalancerWithRewards} from "../../contracts/RebalancerWithRewards.sol";
import {InvalidProvider} from "../../contracts/mocks/MockProvider.sol";
import {MockingUtilities} from "../utils/MockingUtilities.sol";

contract RebalancerWithRewardsTests is MockingUtilities {
    InvalidProvider public invalidProvider;

    event FeeCharged(address indexed treasury, uint256 assets, uint256 fee);
    event RebalanceExecuted(
        uint256 assetsFrom,
        uint256 assetsTo,
        address indexed from,
        address indexed to
    );
    event RewardsTransferred(address indexed to, uint256 amount);
    event DistributorUpdated(address indexed rewardsDistributor);

    function setUp() public {
        invalidProvider = new InvalidProvider();

        initializeVault(vaultWithRewards, MIN_AMOUNT, initializer);

        executeDeposit(vaultWithRewards, DEPOSIT_AMOUNT, alice);
        executeDeposit(vaultWithRewards, DEPOSIT_AMOUNT, bob);
    }

    // =========================================
    // constructor
    // =========================================

    function testConstructor() public view {
        assertEq(
            vaultWithRewards.rewardsDistributor(),
            address(rewardsDistributor)
        );
    }

    // =========================================
    // rebalance
    // =========================================

    function testRebalanceRevertsIfCallerIsNotOperator() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;
        uint256 fee = (assets * REBALANCE_FEE_PERCENT) / PRECISION_FACTOR;

        vm.expectRevert(
            AccessManager.AccessManager__CallerIsNotOperator.selector
        );
        vm.prank(alice);
        vaultWithRewards.rebalance(
            assets,
            mockProviderA,
            mockProviderB,
            fee,
            true
        );
    }

    function testRebalanceRevertsIfProviderIsInvalid() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;
        uint256 fee = (assets * REBALANCE_FEE_PERCENT) / PRECISION_FACTOR;

        vm.expectRevert(
            RebalancerWithRewards
                .RebalancerWithRewards__InvalidProvider
                .selector
        );
        vaultWithRewards.rebalance(
            assets,
            invalidProvider,
            mockProviderB,
            fee,
            true
        );

        vm.expectRevert(
            RebalancerWithRewards
                .RebalancerWithRewards__InvalidProvider
                .selector
        );
        vaultWithRewards.rebalance(
            assets,
            mockProviderA,
            invalidProvider,
            fee,
            true
        );
    }

    function testRebalanceRevertsIfFeeIsNotReasonable() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;
        uint256 excessFee = (assets * MAX_REBALANCE_FEE_PERCENT) /
            PRECISION_FACTOR +
            1;

        vm.expectRevert(
            RebalancerWithRewards
                .RebalancerWithRewards__ExcessRebalanceFee
                .selector
        );
        vaultWithRewards.rebalance(
            assets,
            mockProviderA,
            mockProviderB,
            excessFee,
            true
        );
    }

    function testRebalance() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;
        uint256 fee = (assets * REBALANCE_FEE_PERCENT) / PRECISION_FACTOR;

        vaultWithRewards.rebalance(
            assets,
            mockProviderA,
            mockProviderB,
            fee,
            true
        );

        assertEq(
            mockProviderA.getDepositBalance(
                address(vaultWithRewards),
                vaultWithRewards
            ),
            MIN_AMOUNT
        );
        assertEq(
            mockProviderB.getDepositBalance(
                address(vaultWithRewards),
                vaultWithRewards
            ),
            assets - fee
        );
        assertEq(asset.balanceOf(treasury), fee);
        assertEq(
            address(vaultWithRewards.activeProvider()),
            address(mockProviderB)
        );
    }

    function testRebalanceEmitsEvent() public {
        uint256 assets = 2 * DEPOSIT_AMOUNT;
        uint256 fee = (assets * REBALANCE_FEE_PERCENT) / PRECISION_FACTOR;

        vm.expectEmit();

        emit FeeCharged(treasury, assets, fee);
        emit RebalanceExecuted(
            assets,
            assets - fee,
            address(mockProviderA),
            address(mockProviderB)
        );
        vaultWithRewards.rebalance(
            assets,
            mockProviderA,
            mockProviderB,
            fee,
            true
        );
    }

    // =========================================
    // transferRewards
    // =========================================

    function testTransferRewards(uint256 rewards) public {
        vm.assume(rewards > 0);

        asset.mint(address(vaultWithRewards), rewards);

        uint256 balanceBefore = asset.balanceOf(address(rewardsDistributor));

        vaultWithRewards.transferRewards(address(asset));

        assertEq(
            asset.balanceOf(address(rewardsDistributor)),
            balanceBefore + rewards
        );
    }

    function testTransferRewardsEmitsEvent(uint256 rewards) public {
        vm.assume(rewards > 0);

        asset.mint(address(vaultWithRewards), rewards);

        vm.expectEmit();
        emit RewardsTransferred(address(rewardsDistributor), rewards);
        vaultWithRewards.transferRewards(address(asset));
    }

    // =========================================
    // setRewardsDistributor
    // =========================================

    function testSetRewardsDistributorRevertsIfCallerIsNotAdmin(
        address _rewardsDistributor
    ) public {
        vm.expectRevert(AccessManager.AccessManager__CallerIsNotAdmin.selector);
        vm.prank(alice);
        vaultWithRewards.setRewardsDistributor(_rewardsDistributor);
    }

    function testSetRewardsDistributorRevertsWhenInvalidDistributor() public {
        vm.expectRevert(
            RebalancerWithRewards.RebalancerWithRewards__AddressZero.selector
        );
        vaultWithRewards.setRewardsDistributor(address(0));
    }

    function testSetRewardsDistributor(address _rewardsDistributor) public {
        vm.assume(_rewardsDistributor != address(0));
        vaultWithRewards.setRewardsDistributor(_rewardsDistributor);

        assertEq(vaultWithRewards.rewardsDistributor(), _rewardsDistributor);
    }

    function testSetRewardsDistributorEmitsEvent(
        address _rewardsDistributor
    ) public {
        vm.assume(_rewardsDistributor != address(0));
        vm.expectEmit();
        emit DistributorUpdated(_rewardsDistributor);
        vaultWithRewards.setRewardsDistributor(_rewardsDistributor);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ProviderManager} from "../../contracts/providers/ProviderManager.sol";
import {AccessManager} from "../../contracts/access/AccessManager.sol";
import {MockingUtilities} from "../utils/MockingUtilities.sol";

contract ProviderManagerTests is MockingUtilities {
    ProviderManager public lenderManager;

    event YieldTokenUpdated(
        string identifier,
        address indexed asset,
        address yieldToken
    );

    event MarketUpdated(
        string identifier,
        address indexed assetOne,
        address indexed assetTwo,
        address market
    );

    function setUp() public {
        lenderManager = new ProviderManager();
    }

    // =========================================
    // setYieldToken
    // =========================================

    function testSetYieldTokenRevertsIfCallerIsNotAdmin(
        string memory identifier,
        address asset,
        address yieldToken
    ) public {
        vm.expectRevert(AccessManager.AccessManager__CallerIsNotAdmin.selector);
        vm.prank(alice);
        lenderManager.setYieldToken(identifier, asset, yieldToken);
    }

    function testSetYieldToken(
        string memory identifier,
        address asset,
        address yieldToken
    ) public {
        lenderManager.setYieldToken(identifier, asset, yieldToken);

        string[] memory lenderIdentifiers = lenderManager.getIdentifiers();

        assertEq(lenderIdentifiers[0], identifier);
        assertEq(lenderManager.getYieldToken(identifier, asset), yieldToken);
    }

    function testSetYieldTokenEmitsEvent(
        string memory identifier,
        address asset,
        address yieldToken
    ) public {
        vm.expectEmit();
        emit YieldTokenUpdated(identifier, asset, yieldToken);
        lenderManager.setYieldToken(identifier, asset, yieldToken);
    }

    // =========================================
    // setMarket
    // =========================================

    function testSetMarketRevertsIfCallerIsNotAdmin(
        string memory identifier,
        address assetOne,
        address assetTwo,
        address market
    ) public {
        vm.expectRevert(AccessManager.AccessManager__CallerIsNotAdmin.selector);
        vm.prank(alice);
        lenderManager.setMarket(identifier, assetOne, assetTwo, market);
    }

    function testSetMarket(
        string memory identifier,
        address assetOne,
        address assetTwo,
        address market
    ) public {
        lenderManager.setMarket(identifier, assetOne, assetTwo, market);

        string[] memory lenderIdentifiers = lenderManager.getIdentifiers();

        assertEq(lenderIdentifiers[0], identifier);
        assertEq(
            lenderManager.getMarket(identifier, assetOne, assetTwo),
            market
        );
    }

    function testSetMarketEmitsEvent(
        string memory identifier,
        address assetOne,
        address assetTwo,
        address market
    ) public {
        vm.expectEmit();
        emit MarketUpdated(identifier, assetOne, assetTwo, market);
        lenderManager.setMarket(identifier, assetOne, assetTwo, market);
    }
}

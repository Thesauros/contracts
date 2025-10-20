// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessManager} from "../../contracts/access/AccessManager.sol";
import {Vault} from "../../contracts/base/Vault.sol";
import {MockingUtilities} from "../utils/MockingUtilities.sol";
import {Vm} from "forge-std/Vm.sol";

contract AccessManagerTests is MockingUtilities {
    AccessManager public accessManager;

    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    function setUp() public {
        accessManager = new AccessManager();
    }

    // =========================================
    // constructor
    // =========================================

    function testConstructor() public view {
        assertTrue(accessManager.hasRole(ADMIN_ROLE, address(this)));
    }

    // =========================================
    // grantRole
    // =========================================

    function testGrantRoleRevertsIfCallerIsNotAdmin() public {
        vm.expectRevert(AccessManager.AccessManager__CallerIsNotAdmin.selector);
        vm.prank(alice);
        accessManager.grantRole(ADMIN_ROLE, alice);
    }

    function testGrantRole() public {
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    function testGrantRoleEmitsEvent() public {
        vm.expectEmit();
        emit RoleGranted(EXECUTOR_ROLE, alice, address(this));
        accessManager.grantRole(EXECUTOR_ROLE, alice);
    }

    // =========================================
    // revokeRole
    // =========================================

    function testRevokeRoleRevertsIfCallerIsNotAdmin() public {
        vm.expectRevert(AccessManager.AccessManager__CallerIsNotAdmin.selector);
        vm.prank(alice);
        accessManager.revokeRole(ADMIN_ROLE, alice);
    }

    function testRevokeRole() public {
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        accessManager.revokeRole(EXECUTOR_ROLE, alice);
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    function testRevokeRoleEmitsEvent() public {
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        vm.expectEmit();
        emit RoleRevoked(EXECUTOR_ROLE, alice, address(this));
        accessManager.revokeRole(EXECUTOR_ROLE, alice);
    }

    // =========================================
    // hasRole
    // =========================================

    function testHasRoleReturnsFalseByDefault() public view {
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    function testHasRoleReturnsTrueAfterGranting() public {
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    function testHasRoleReturnsFalseAfterRevoking() public {
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        accessManager.revokeRole(EXECUTOR_ROLE, alice);
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    // =========================================
    // role constants
    // =========================================

    function testRoleConstants() public view {
        assertEq(accessManager.ADMIN_ROLE(), 0x00);
        assertEq(accessManager.OPERATOR_ROLE(), keccak256("OPERATOR_ROLE"));
        assertEq(accessManager.EXECUTOR_ROLE(), keccak256("EXECUTOR_ROLE"));
        assertEq(accessManager.DEPOSITOR_ROLE(), keccak256("DEPOSITOR_ROLE"));
    }

    // =========================================
    // multiple roles
    // =========================================

    function testMultipleRoles() public {
        // Grant multiple roles to alice
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        accessManager.grantRole(OPERATOR_ROLE, alice);
        accessManager.grantRole(DEPOSITOR_ROLE, alice);

        // Check all roles are granted
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, alice));
        assertTrue(accessManager.hasRole(OPERATOR_ROLE, alice));
        assertTrue(accessManager.hasRole(DEPOSITOR_ROLE, alice));

        // Revoke one role
        accessManager.revokeRole(EXECUTOR_ROLE, alice);
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, alice));
        assertTrue(accessManager.hasRole(OPERATOR_ROLE, alice));
        assertTrue(accessManager.hasRole(DEPOSITOR_ROLE, alice));
    }

    // =========================================
    // grant role to same account twice
    // =========================================

    function testGrantRoleToSameAccountTwice() public {
        // Grant role first time
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, alice));

        // Grant same role again - should not emit event
        vm.recordLogs();
        accessManager.grantRole(EXECUTOR_ROLE, alice);
        
        // Check that no events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Should not emit any events on second grant");
        
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    // =========================================
    // revoke role from account without role
    // =========================================

    function testRevokeRoleFromAccountWithoutRole() public {
        // Try to revoke role from account that doesn't have it
        vm.recordLogs();
        accessManager.revokeRole(EXECUTOR_ROLE, alice);
        
        // Check that no events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "Should not emit any events when revoking from account without role");
        
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, alice));
    }

    // =========================================
    // grant role to zero address
    // =========================================

    function testGrantRoleToZeroAddress() public {
        // Should not revert, but also shouldn't be useful
        accessManager.grantRole(EXECUTOR_ROLE, address(0));
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, address(0)));
    }

    // =========================================
    // revoke role from zero address
    // =========================================

    function testRevokeRoleFromZeroAddress() public {
        // Grant role to zero address first
        accessManager.grantRole(EXECUTOR_ROLE, address(0));
        
        // Then revoke it
        accessManager.revokeRole(EXECUTOR_ROLE, address(0));
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, address(0)));
    }

    // =========================================
    // admin role management
    // =========================================

    function testAdminCanGrantAdminRole() public {
        // Current admin (this contract) grants admin role to alice
        accessManager.grantRole(ADMIN_ROLE, alice);
        assertTrue(accessManager.hasRole(ADMIN_ROLE, alice));
    }

    function testAdminCanRevokeAdminRole() public {
        // Grant admin role to alice
        accessManager.grantRole(ADMIN_ROLE, alice);
        
        // Revoke admin role from alice
        accessManager.revokeRole(ADMIN_ROLE, alice);
        assertFalse(accessManager.hasRole(ADMIN_ROLE, alice));
    }

    function testNewAdminCanGrantRoles() public {
        // Grant admin role to alice
        accessManager.grantRole(ADMIN_ROLE, alice);
        
        // Alice should now be able to grant roles
        vm.prank(alice);
        accessManager.grantRole(EXECUTOR_ROLE, bob);
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, bob));
    }

    // =========================================
    // fuzz testing
    // =========================================

    function testFuzzHasRole(address account) public view {
        // By default, only deployer should have ADMIN_ROLE
        if (account == address(this)) {
            assertTrue(accessManager.hasRole(ADMIN_ROLE, account));
        } else {
            assertFalse(accessManager.hasRole(ADMIN_ROLE, account));
        }
    }

    function testFuzzGrantRevokeRole(address account) public {
        vm.assume(account != address(0));
        
        // Grant role
        accessManager.grantRole(EXECUTOR_ROLE, account);
        assertTrue(accessManager.hasRole(EXECUTOR_ROLE, account));
        
        // Revoke role
        accessManager.revokeRole(EXECUTOR_ROLE, account);
        assertFalse(accessManager.hasRole(EXECUTOR_ROLE, account));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Timelock} from "../../contracts/Timelock.sol";
import {MockingUtilities} from "../utils/MockingUtilities.sol";

contract TimelockTests is MockingUtilities {
    address public target;
    string public signature;
    uint256 public timestamp;

    event DelayUpdated(uint256 indexed newDelay);
    event Queued(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );
    event Cancelled(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );
    event Executed(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );

    function setUp() public {
        target = address(timelock);
        signature = "setDelay(uint256)";
        timestamp = block.timestamp + TIMELOCK_DELAY;
    }

    // =========================================
    // constructor
    // =========================================

    function testConstructor() public view {
        assertEq(timelock.owner(), address(this));
        assertEq(timelock.delay(), TIMELOCK_DELAY);
    }

    // =========================================
    // queue
    // =========================================

    function testQueueRevertsIfCallerIsNotOwner() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        vm.prank(alice);
        timelock.queue(target, 0, signature, data, timestamp);
    }

    function testQueueRevertsIfTimestampIsInvalid() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        uint256 invalidTimestamp = timestamp - 1;

        vm.expectRevert(Timelock.Timelock__InvalidTimestamp.selector);
        timelock.queue(target, 0, signature, data, invalidTimestamp);
    }

    function testQueue() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        assertTrue(timelock.queued(txId));
    }

    function testQueueEmitsEvent() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        vm.expectEmit();
        emit Queued(txId, target, 0, signature, data, timestamp);
        timelock.queue(target, 0, signature, data, timestamp);
    }

    // =========================================
    // cancel
    // =========================================

    function testCancelRevertsIfCallerIsNotOwner() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        vm.prank(alice);
        timelock.cancel(target, 0, signature, data, timestamp);
    }

    function testCancel() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        assertTrue(timelock.queued(txId));

        timelock.cancel(target, 0, signature, data, timestamp);

        assertFalse(timelock.queued(txId));
    }

    function testCancelEmitsEvent() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        vm.expectEmit();
        emit Cancelled(txId, target, 0, signature, data, timestamp);
        timelock.cancel(target, 0, signature, data, timestamp);
    }

    // =========================================
    // execute
    // =========================================

    function testExecuteRevertsIfCallerIsNotOwner() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        vm.prank(alice);
        timelock.execute(target, 0, signature, data, timestamp);
    }

    function testExecuteRevertsIfTransactionIsNotQueued() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        vm.expectRevert(Timelock.Timelock__NotQueued.selector);
        timelock.execute(target, 0, signature, data, timestamp);
    }

    function testExecuteRevertsIfTransactionIsStillLocked() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        vm.expectRevert(Timelock.Timelock__StillLocked.selector);
        timelock.execute(target, 0, signature, data, timestamp);
    }

    function testExecuteRevertsIfTransactionIsExpired() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        vm.warp(timestamp + TIMELOCK_GRACE_PERIOD + 1);

        vm.expectRevert(Timelock.Timelock__Expired.selector);
        timelock.execute(target, 0, signature, data, timestamp);
    }

    function testExecuteRevertsIfTargetExecutionFails() public {
        uint256 invalidDelay = 1 seconds;
        bytes memory invalidData = abi.encode(invalidDelay);

        timelock.queue(target, 0, signature, invalidData, timestamp);

        vm.warp(timestamp);

        vm.expectRevert(Timelock.Timelock__ExecutionFailed.selector);
        timelock.execute(target, 0, signature, invalidData, timestamp);
    }

    function testExecute() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        vm.warp(timestamp);

        timelock.execute(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        assertFalse(timelock.queued(txId));
        assertEq(timelock.delay(), newDelay);
    }

    function testExecuteEmitsEvent() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        vm.warp(timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );

        vm.expectEmit();
        emit DelayUpdated(newDelay);
        emit Executed(txId, target, 0, signature, data, timestamp);
        timelock.execute(target, 0, signature, data, timestamp);
    }

    // =========================================
    // setDelay
    // =========================================

    function testSetDelayRevertsIfCallerIsNotTimelock() public {
        uint256 newDelay = 1 days;

        vm.expectRevert(Timelock.Timelock__Unauthorized.selector);
        timelock.setDelay(newDelay);
    }

    function testSetDelayThroughExecute() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        // Queue the setDelay transaction
        timelock.queue(target, 0, signature, data, timestamp);

        // Execute after delay
        vm.warp(timestamp);
        timelock.execute(target, 0, signature, data, timestamp);

        // Verify delay was updated
        assertEq(timelock.delay(), newDelay);
    }

    // =========================================
    // receive and fallback
    // =========================================

    function testReceive() public {
        uint256 initialBalance = address(timelock).balance;
        uint256 sendAmount = 1 ether;

        // Send ETH to timelock
        (bool success,) = address(timelock).call{value: sendAmount}("");
        assertTrue(success);
        assertEq(address(timelock).balance, initialBalance + sendAmount);
    }

    function testFallback() public {
        uint256 initialBalance = address(timelock).balance;
        uint256 sendAmount = 1 ether;

        // Send ETH to timelock with data (triggers fallback)
        (bool success,) = address(timelock).call{value: sendAmount}("0x1234");
        assertTrue(success);
        assertEq(address(timelock).balance, initialBalance + sendAmount);
    }

    // =========================================
    // execute with empty signature
    // =========================================

    function testExecuteWithEmptySignature() public {
        string memory emptySignature = "";
        bytes memory data = abi.encode(1 days);

        // Queue transaction with empty signature
        timelock.queue(target, 0, emptySignature, data, timestamp);

        // Execute after delay
        vm.warp(timestamp);
        timelock.execute(target, 0, emptySignature, data, timestamp);

        // Verify transaction was executed (queued set to false)
        bytes32 txId = keccak256(
            abi.encode(target, 0, emptySignature, data, timestamp)
        );
        assertFalse(timelock.queued(txId));
    }

    // =========================================
    // execute with ETH value
    // =========================================

    function testExecuteWithValue() public {
        uint256 sendAmount = 1 ether;
        
        // Send ETH to timelock first
        (bool success,) = address(timelock).call{value: sendAmount}("");
        assertTrue(success);

        // Create a transaction that sends ETH
        address payable targetAddress = payable(alice);
        uint256 initialBalance = alice.balance;
        
        timelock.queue(targetAddress, sendAmount, "", "", timestamp);

        // Execute after delay
        vm.warp(timestamp);
        timelock.execute{value: sendAmount}(targetAddress, sendAmount, "", "", timestamp);

        // Verify ETH was sent
        assertEq(alice.balance, initialBalance + sendAmount);
    }

    // =========================================
    // edge cases
    // =========================================

    function testQueueWithMaxDelay() public {
        uint256 maxDelay = 30 days;
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);
        uint256 maxTimestamp = block.timestamp + maxDelay;

        // Should succeed with max delay
        timelock.queue(target, 0, signature, data, maxTimestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, maxTimestamp)
        );
        assertTrue(timelock.queued(txId));
    }

    function testQueueWithMinDelay() public {
        uint256 minDelay = 30 minutes;
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);
        uint256 minTimestamp = block.timestamp + minDelay;

        // Should succeed with min delay
        timelock.queue(target, 0, signature, data, minTimestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, minTimestamp)
        );
        assertTrue(timelock.queued(txId));
    }

    function testExecuteAtExactTimestamp() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        // Execute at exact timestamp
        vm.warp(timestamp);
        timelock.execute(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );
        assertFalse(timelock.queued(txId));
    }

    function testExecuteAtGracePeriodEnd() public {
        uint256 newDelay = 1 days;
        bytes memory data = abi.encode(newDelay);

        timelock.queue(target, 0, signature, data, timestamp);

        // Execute at the very end of grace period
        vm.warp(timestamp + TIMELOCK_GRACE_PERIOD);
        timelock.execute(target, 0, signature, data, timestamp);

        bytes32 txId = keccak256(
            abi.encode(target, 0, signature, data, timestamp)
        );
        assertFalse(timelock.queued(txId));
    }
}

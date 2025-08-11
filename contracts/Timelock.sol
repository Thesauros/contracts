// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Timelock
 */
contract Timelock is Ownable2Step {
    /**
     * @dev Errors
     */
    error Timelock__Unauthorized();
    error Timelock__InvalidDelay();
    error Timelock__InvalidTimestamp();
    error Timelock__NotQueued();
    error Timelock__StillLocked();
    error Timelock__Expired();
    error Timelock__ExecutionFailed();

    // Transaction ids => queued
    mapping(bytes32 => bool) public queued;

    uint256 public constant MIN_DELAY = 30 minutes;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    uint256 public delay;

    /**
     * @dev Emitted when the delay for queued transactions is updated.
     */
    event DelayUpdated(uint256 indexed newDelay);

    /**
     * @dev Emitted when a transaction is queued.
     */
    event Queued(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a queued transaction is executed.
     */
    event Executed(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a queued transaction is cancelled.
     */
    event Cancelled(
        bytes32 indexed txId,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 timestamp
    );

    /**
     * @dev Reverts if called by any account other than the contract itself.
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert Timelock__Unauthorized();
        }
        _;
    }

    /**
     * @dev Initializes the Timelock contract with the specified parameters.
     * @param owner_ The address of the initial owner of the contract.
     * @param delay_ The initial delay for queued transactions.
     */
    constructor(address owner_, uint256 delay_) Ownable(owner_) {
        _setDelay(delay_);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @notice Queues a transaction.
     * @param target The address of the contract to call.
     * @param value The amount of ether to send with the call.
     * @param signature The function signature of the target contract.
     * @param data The calldata for the function called on the target address.
     * @param timestamp The time when the transaction can be executed.
     */
    function queue(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 timestamp
    ) public onlyOwner returns (bytes32) {
        if (timestamp < block.timestamp + delay) {
            revert Timelock__InvalidTimestamp();
        }

        bytes32 txId = keccak256(
            abi.encode(target, value, signature, data, timestamp)
        );
        queued[txId] = true;

        emit Queued(txId, target, value, signature, data, timestamp);
        return txId;
    }

    /**
     * @notice Cancels a queued transaction.
     * @param target The address of the contract to cancel the transaction for.
     * @param value The amount of ether that was to be sent with the call.
     * @param signature The function signature of the target contract.
     * @param data The calldata for the function called on the target address.
     * @param timestamp The time when the transaction was scheduled to be executed.
     */
    function cancel(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 timestamp
    ) public onlyOwner {
        bytes32 txId = keccak256(
            abi.encode(target, value, signature, data, timestamp)
        );
        queued[txId] = false;

        emit Cancelled(txId, target, value, signature, data, timestamp);
    }

    /**
     * @notice Executes a queued transaction.
     * @param target The address of the contract to call.
     * @param value The amount of ether to send with the call.
     * @param signature The function signature of the target contract.
     * @param data The calldata for the function called.
     * @param timestamp The time when the transaction can be executed.
     */
    function execute(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 timestamp
    ) public payable onlyOwner returns (bytes memory) {
        bytes32 txId = keccak256(
            abi.encode(target, value, signature, data, timestamp)
        );

        if (!queued[txId]) {
            revert Timelock__NotQueued();
        }
        if (block.timestamp < timestamp) {
            revert Timelock__StillLocked();
        }
        if (block.timestamp > timestamp + GRACE_PERIOD) {
            revert Timelock__Expired();
        }

        queued[txId] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        if (!success) {
            revert Timelock__ExecutionFailed();
        }

        emit Executed(txId, target, value, signature, data, timestamp);

        return returnData;
    }

    /**
     * @notice Sets a new delay for queued transactions.
     * @param _delay The new delay duration in seconds.
     */
    function setDelay(uint256 _delay) public onlySelf {
        _setDelay(_delay);
    }

    /**
     * @dev Internal function to set the delay.
     * @param _delay The new delay duration in seconds.
     */
    function _setDelay(uint256 _delay) internal {
        if (_delay < MIN_DELAY || _delay > MAX_DELAY) {
            revert Timelock__InvalidDelay();
        }

        delay = _delay;
        emit DelayUpdated(_delay);
    }
}

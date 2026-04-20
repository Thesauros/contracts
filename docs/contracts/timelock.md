# Timelock

Contract for secure governance of critical operations with transaction execution delay.

**File:** `contracts/Timelock.sol`

## Overview

Timelock ensures security of critical operations in the Thesauros system through a transaction execution delay mechanism. This allows the community and stakeholders to analyze and, if necessary, cancel potentially dangerous transactions.

## Constructor

```solidity
constructor(address owner_, uint256 delay_)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `owner_` | `address` | Contract owner address |
| `delay_` | `uint256` | Transaction execution delay (30 minutes - 30 days) |

### Limitations

- `delay_` must be in the range from `MIN_DELAY` (30 minutes) to `MAX_DELAY` (30 days)

## Main Methods

### queue(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)

Queues a transaction for execution.

```solidity
function queue(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 timestamp
) external onlyOwner
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `address` | Target contract address |
| `value` | `uint256` | Amount of ETH to send |
| `signature` | `string` | Function signature |
| `data` | `bytes` | Call data |
| `timestamp` | `uint256` | Execution time |

#### Limitations

- Can only be called by owner (`onlyOwner`)
- `timestamp` must be at least current time + `delay`
- `timestamp` must be at most current time + `delay` + `GRACE_PERIOD`

#### Events

```solidity
event Queued(
    bytes32 indexed txId,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 timestamp
);
```

### execute(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)

Executes a queued transaction.

```solidity
function execute(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 timestamp
) external payable onlyOwner
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `address` | Target contract address |
| `value` | `uint256` | Amount of ETH to send |
| `signature` | `string` | Function signature |
| `data` | `bytes` | Call data |
| `timestamp` | `uint256` | Execution time |

#### Limitations

- Can only be called by owner (`onlyOwner`)
- Transaction must be queued
- Current time must be at least `timestamp`
- Current time must be at most `timestamp` + `GRACE_PERIOD`

#### Events

```solidity
event Executed(
    bytes32 indexed txId,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 timestamp
);
```

### cancel(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)

Cancels a queued transaction.

```solidity
function cancel(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 timestamp
) external onlyOwner
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `address` | Target contract address |
| `value` | `uint256` | Amount of ETH to send |
| `signature` | `string` | Function signature |
| `data` | `bytes` | Call data |
| `timestamp` | `uint256` | Execution time |

#### Limitations

- Can only be called by owner (`onlyOwner`)
- Transaction must be queued

#### Events

```solidity
event Cancelled(
    bytes32 indexed txId,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 timestamp
);
```

## Management Methods

### setDelay(uint256 _delay)

Sets a new execution delay.

```solidity
function setDelay(uint256 _delay) external onlySelf
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_delay` | `uint256` | New execution delay |

#### Limitations

- Can only be called by the contract itself (`onlySelf`)
- `_delay` must be in the range from `MIN_DELAY` to `MAX_DELAY`

#### Events

```solidity
event DelayUpdated(uint256 indexed newDelay);
```

## View Methods

### getTxId(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)

Calculates the transaction ID.

```solidity
function getTxId(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 timestamp
) public pure returns (bytes32)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `target` | `address` | Target contract address |
| `value` | `uint256` | Amount of ETH to send |
| `signature` | `string` | Function signature |
| `data` | `bytes` | Call data |
| `timestamp` | `uint256` | Execution time |

#### Returns

- `bytes32` - Unique transaction identifier

### queued(bytes32 txId)

Checks if a transaction is queued.

```solidity
function queued(bytes32 txId) public view returns (bool)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `txId` | `bytes32` | Transaction ID |

#### Returns

- `bool` - `true` if transaction is queued, `false` otherwise

## Transaction Lifecycle

### 1. Queue Phase

```solidity
// Queue a transaction
timelock.queue(
    target,     // Target contract
    value,      // ETH amount
    signature,  // Function signature
    data,       // Call data
    timestamp   // Execution time
);
```

### 2. Waiting Period

- Transaction waits for `delay` period
- Community can review the transaction
- Owner can cancel if needed

### 3. Execution Window

```solidity
// Execute after delay period
timelock.execute(
    target,     // Same parameters as queue
    value,
    signature,
    data,
    timestamp
);
```

### 4. Grace Period

- Transaction can be executed for `GRACE_PERIOD` after `timestamp`
- After grace period, transaction expires

## Usage Examples

### Setting Vault Providers

```solidity
// Queue provider update
timelock.queue(
    vault,                          // Vault contract
    0,                              // No ETH
    "setProviders(address[])",      // Function signature
    abi.encode(newProviders),       // Encoded parameters
    block.timestamp + delay         // Execution time
);

// Execute after delay
timelock.execute(
    vault,
    0,
    "setProviders(address[])",
    abi.encode(newProviders),
    block.timestamp + delay
);
```

### Emergency Cancellation

```solidity
// Cancel queued transaction
timelock.cancel(
    vault,
    0,
    "setProviders(address[])",
    abi.encode(newProviders),
    block.timestamp + delay
);
```

### Delay Update

```solidity
// Update delay through timelock itself
timelock.queue(
    timelock,                       // Self
    0,                              // No ETH
    "setDelay(uint256)",            // Function signature
    abi.encode(newDelay),           // New delay
    block.timestamp + delay         // Execution time
);
```

## Security Features

### Delay Protection

- Minimum delay: 30 minutes
- Maximum delay: 30 days
- Prevents immediate execution of critical operations

### Grace Period

- 14-day grace period for execution
- Prevents transactions from being stuck forever
- Allows for emergency execution if needed

### Access Control

- Only owner can queue, execute, and cancel
- Contract can update its own delay
- No direct execution bypass

### Transaction Validation

- Timestamp validation prevents replay attacks
- Signature and data integrity checks
- Unique transaction ID generation

## Constants

```solidity
uint256 public constant MIN_DELAY = 30 minutes;
uint256 public constant MAX_DELAY = 30 days;
uint256 public constant GRACE_PERIOD = 14 days;
```

## State Variables

```solidity
address public owner;
uint256 public delay;
mapping(bytes32 => bool) public queued;
```

## Events

```solidity
event DelayUpdated(uint256 indexed newDelay);
event Queued(
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
event Cancelled(
    bytes32 indexed txId,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 timestamp
);
```

## Errors

```solidity
error Timelock__Unauthorized();
error Timelock__InvalidDelay();
error Timelock__InvalidTimestamp();
error Timelock__NotQueued();
error Timelock__StillLocked();
error Timelock__Expired();
error Timelock__ExecutionFailed();
```

### Error Descriptions

- `Timelock__Unauthorized()` - Caller is not authorized
- `Timelock__InvalidDelay()` - Delay is outside allowed range
- `Timelock__InvalidTimestamp()` - Timestamp is invalid
- `Timelock__NotQueued()` - Transaction is not queued
- `Timelock__StillLocked()` - Transaction is still in delay period
- `Timelock__Expired()` - Transaction has expired
- `Timelock__ExecutionFailed()` - Transaction execution failed

## Modifiers

```solidity
modifier onlyOwner() {
    if (msg.sender != owner) {
        revert Timelock__Unauthorized();
    }
    _;
}

modifier onlySelf() {
    if (msg.sender != address(this)) {
        revert Timelock__Unauthorized();
    }
    _;
}
```

## Best Practices

### Delay Selection

- Use longer delays for critical operations
- Consider community response time
- Balance security with operational efficiency

### Transaction Design

- Keep transactions atomic
- Use clear function signatures
- Include sufficient documentation

### Monitoring

- Track queued transactions
- Monitor execution patterns
- Alert on unusual activity

## Integration

### With Vault

```solidity
// Vault calls timelock for critical operations
function setProviders(IProvider[] memory providers) external onlyTimelock {
    // Update providers
}
```

### With VaultManager

```solidity
// VaultManager uses timelock for governance
function updateSettings() external onlyTimelock {
    // Update settings
}
```

## Testing

### Unit Tests

```solidity
function testQueueAndExecute() public {
    // Queue transaction
    timelock.queue(target, 0, signature, data, timestamp);
    
    // Fast forward time
    vm.warp(timestamp);
    
    // Execute
    timelock.execute(target, 0, signature, data, timestamp);
}
```

### Integration Tests

```solidity
function testTimelockWithVault() public {
    // Queue vault operation
    timelock.queue(vault, 0, "setProviders(address[])", data, timestamp);
    
    // Execute after delay
    vm.warp(timestamp);
    timelock.execute(vault, 0, "setProviders(address[])", data, timestamp);
    
    // Verify vault state
    assertEq(vault.getProviders().length, newProviderCount);
}
``` 
# VaultManager

Centralized manager for managing multiple vaults and performing rebalancing.

**File:** `contracts/VaultManager.sol`

## Overview

VaultManager provides a centralized interface for managing multiple vaults. It allows performing rebalancing for any vault in the system through a single entry point, simplifying management and monitoring.

## Constructor

```solidity
constructor()
```

The contract does not require parameters in the constructor, as all settings are performed through management methods.

## Main Methods

### rebalanceVault(IVault vault, uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)

Performs rebalancing for the specified vault.

```solidity
function rebalanceVault(
    IVault vault,
    uint256 assets,
    IProvider from,
    IProvider to,
    uint256 fee,
    bool activateToProvider
) external onlyExecutor returns (bool success)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vault` | `IVault` | Address of vault for rebalancing |
| `assets` | `uint256` | Amount of assets (type(uint256).max for all funds) |
| `from` | `IProvider` | Provider from which funds are withdrawn |
| `to` | `IProvider` | Provider to which funds are deposited |
| `fee` | `uint256` | Rebalancing fee |
| `activateToProvider` | `bool` | Flag to activate the new provider |

#### Returns

- `bool success` - `true` on successful execution

#### Limitations

- Can only be called by executor (`onlyExecutor`)
- `assets` cannot be 0
- `assets` cannot exceed balance at provider `from`
- `vault` must be a valid contract

#### Execution Logic

1. **Balance Check** - get current balance at provider `from`
2. **Amount Validation** - verify that `assets` does not exceed available balance
3. **Maximum Amount Handling** - if `assets = type(uint256).max`, use entire available balance
4. **Rebalancing Execution** - call `rebalance()` method on specified vault
5. **Result Return** - return `true` on successful execution

#### Usage Examples

```solidity
// Rebalance 1000 USDC in USDC vault
vaultManager.rebalanceVault(
    usdcVault,           // USDC vault
    1000e6,             // 1000 USDC
    aaveProvider,       // from Aave
    compoundProvider,   // to Compound
    10e6,               // 10 USDC fee
    true                // activate Compound
);

// Rebalance all funds in DAI vault
vaultManager.rebalanceVault(
    daiVault,           // DAI vault
    type(uint256).max,  // all funds
    compoundProvider,   // from Compound
    aaveProvider,       // to Aave
    0,                  // no fee
    false               // don't activate Aave
);
```

## Management Methods

### setExecutor(address _executor)

Sets the executor address.

```solidity
function setExecutor(address _executor) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_executor` | `address` | New executor address |

#### Limitations

- Can only be called by admin (`onlyAdmin`)
- `_executor` cannot be a zero address

#### Events

```solidity
event ExecutorUpdated(address indexed executor);
```

### setAdmin(address _admin)

Sets the admin address.

```solidity
function setAdmin(address _admin) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_admin` | `address` | New admin address |

#### Limitations

- Can only be called by admin (`onlyAdmin`)
- `_admin` cannot be a zero address

#### Events

```solidity
event AdminUpdated(address indexed admin);
```

## View Methods

### executor()

Returns the current executor address.

```solidity
function executor() public view returns (address)
```

#### Returns

- `address` - Current executor address

### admin()

Returns the current admin address.

```solidity
function admin() public view returns (address)
```

#### Returns

- `address` - Current admin address

## Rebalancing Process

### Step-by-Step Execution

1. **Input Validation**
   ```solidity
   // Validate asset amount
   if (assets == 0) {
       revert VaultManager__InvalidAssetAmount();
   }
   ```

2. **Balance Retrieval**
   ```solidity
   // Get current balance at source provider
   uint256 currentBalance = vault.getBalanceOfProvider(from);
   ```

3. **Amount Calculation**
   ```solidity
   // Handle maximum amount case
   uint256 rebalanceAmount = assets;
   if (assets == type(uint256).max) {
       rebalanceAmount = currentBalance;
   }
   
   // Validate amount
   if (rebalanceAmount > currentBalance) {
       revert VaultManager__InvalidAssetAmount();
   }
   ```

4. **Rebalancing Execution**
   ```solidity
   // Execute rebalancing on vault
   bool success = vault.rebalance(
       rebalanceAmount,
       from,
       to,
       fee,
       activateToProvider
   );
   
   return success;
   ```

## Usage Examples

### Basic Rebalancing

```solidity
// Rebalance specific amount
vaultManager.rebalanceVault(
    vault,              // Vault address
    1000e6,            // 1000 tokens
    providerA,         // From provider
    providerB,         // To provider
    50e6,              // 50 token fee
    true               // Activate new provider
);
```

### Emergency Rebalancing

```solidity
// Rebalance all funds in emergency
vaultManager.rebalanceVault(
    vault,                 // Vault address
    type(uint256).max,     // All funds
    riskyProvider,         // From risky provider
    safeProvider,          // To safe provider
    100e6,                 // Emergency fee
    true                   // Activate safe provider
);
```

### Fee-Free Rebalancing

```solidity
// Rebalance without fee
vaultManager.rebalanceVault(
    vault,              // Vault address
    500e6,             // 500 tokens
    providerA,         // From provider
    providerB,         // To provider
    0,                 // No fee
    false              // Don't activate
);
```

## Security Features

### Access Control

- Only executors can perform rebalancing
- Only admins can update settings
- Role-based access prevents unauthorized operations

### Input Validation

- Asset amount validation
- Provider validation through vault
- Zero address checks

### Error Handling

- Comprehensive error messages
- Graceful failure handling
- State consistency maintenance

## Integration

### With Vault

```solidity
// VaultManager calls vault for rebalancing
function rebalanceVault(...) external onlyExecutor returns (bool) {
    return vault.rebalance(assets, from, to, fee, activateToProvider);
}
```

### With Timelock

```solidity
// Timelock can control VaultManager
function setExecutor(address _executor) external onlyTimelock {
    executor = _executor;
    emit ExecutorUpdated(_executor);
}
```

## Events

### ExecutorUpdated

Emitted when executor is updated.

```solidity
event ExecutorUpdated(address indexed executor);
```

### AdminUpdated

Emitted when admin is updated.

```solidity
event AdminUpdated(address indexed admin);
```

## Errors

```solidity
error VaultManager__InvalidAssetAmount();
```

### Error Descriptions

- `VaultManager__InvalidAssetAmount()` - Asset amount is invalid (0 or exceeds balance)

## State Variables

```solidity
address public admin;
address public executor;
```

## Modifiers

```solidity
modifier onlyAdmin() {
    if (msg.sender != admin) {
        revert VaultManager__Unauthorized();
    }
    _;
}

modifier onlyExecutor() {
    if (msg.sender != executor) {
        revert VaultManager__Unauthorized();
    }
    _;
}
```

## Best Practices

### Rebalancing Strategy

- Monitor provider performance regularly
- Use appropriate fees for different scenarios
- Consider gas costs when rebalancing

### Access Management

- Use timelock for critical operations
- Maintain role separation
- Regular access review

### Monitoring

- Track rebalancing frequency
- Monitor fee collection
- Analyze yield improvements

## Testing

### Unit Tests

```solidity
function testRebalanceVault() public {
    // Setup
    uint256 amount = 1000e6;
    
    // Execute
    bool success = vaultManager.rebalanceVault(
        vault, amount, providerA, providerB, 0, true
    );
    
    // Verify
    assertTrue(success);
}
```

### Integration Tests

```solidity
function testRebalanceAllFunds() public {
    // Setup
    uint256 totalBalance = vault.totalAssets();
    
    // Execute
    vaultManager.rebalanceVault(
        vault, type(uint256).max, providerA, providerB, 0, false
    );
    
    // Verify
    assertEq(vault.getBalanceOfProvider(providerB), totalBalance);
}
```

## Gas Optimization

### Efficient Rebalancing

```solidity
// Optimize for maximum amount case
if (assets == type(uint256).max) {
    // Skip balance check, use direct rebalancing
    return vault.rebalance(currentBalance, from, to, fee, activateToProvider);
}
```

### Batch Operations

```solidity
// Batch rebalance multiple vaults
function batchRebalance(
    IVault[] memory vaults,
    uint256[] memory amounts,
    IProvider[] memory fromProviders,
    IProvider[] memory toProviders,
    uint256[] memory fees,
    bool[] memory activateFlags
) external onlyExecutor {
    for (uint256 i = 0; i < vaults.length; i++) {
        rebalanceVault(
            vaults[i],
            amounts[i],
            fromProviders[i],
            toProviders[i],
            fees[i],
            activateFlags[i]
        );
    }
}
``` 
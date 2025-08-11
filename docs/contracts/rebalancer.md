# Rebalancer

Contract for rebalancing funds between different liquidity providers to maximize yield.

**File:** `contracts/Rebalancer.sol`

## Overview

Rebalancer inherits from Vault and adds functionality for redistributing funds between providers. This allows automatic yield optimization by moving funds to the most profitable protocols.

## Constructor

```solidity
constructor(
    address asset_,
    string memory name_,
    string memory symbol_,
    IProvider[] memory providers_,
    uint256 withdrawFeePercent_,
    address timelock_,
    address treasury_
)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `asset_` | `address` | Address of the underlying asset (ERC20 token) |
| `name_` | `string` | Vault token name |
| `symbol_` | `string` | Vault token symbol |
| `providers_` | `IProvider[]` | Array of liquidity providers |
| `withdrawFeePercent_` | `uint256` | Withdrawal fee percentage (maximum 5%) |
| `timelock_` | `address` | Timelock contract address |
| `treasury_` | `address` | Treasury address |

## Main Methods

### rebalance(uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)

Performs rebalancing of funds between providers.

```solidity
function rebalance(
    uint256 assets,
    IProvider from,
    IProvider to,
    uint256 fee,
    bool activateToProvider
) external onlyOperator returns (bool)
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `assets` | `uint256` | Amount of assets for rebalancing |
| `from` | `IProvider` | Provider from which funds are withdrawn |
| `to` | `IProvider` | Provider to which funds are deposited |
| `fee` | `uint256` | Rebalancing fee (maximum 20% of amount) |
| `activateToProvider` | `bool` | Flag to activate the new provider |

#### Returns

- `bool` - `true` on successful execution

#### Limitations

- Can only be called by operator (`onlyOperator`)
- `from` and `to` must be valid providers
- `fee` cannot exceed 20% of `assets`
- `from` and `to` cannot be the same

#### Execution Logic

1. **Provider Validation** - check that `from` and `to` are in the provider list
2. **Fee Check** - validate that fee does not exceed limit
3. **Withdraw Funds** - withdraw `assets` from provider `from`
4. **Deposit Funds** - deposit `assets - fee` to provider `to`
5. **Transfer Fee** - if `fee > 0`, transfer to treasury
6. **Activate Provider** - if `activateToProvider = true`, set `to` as active provider

#### Events

```solidity
event FeeCharged(address indexed treasury, uint256 assets, uint256 fee);
event RebalanceExecuted(
    uint256 assetsFrom,
    uint256 assetsTo,
    address indexed from,
    address indexed to
);
```

### receive()

Allows the contract to receive ETH.

```solidity
receive() external payable {}
```

## Rebalancing Process

### Step-by-Step Execution

1. **Validation Phase**
   ```solidity
   // Check if providers are valid
   if (!isProvider(from) || !isProvider(to)) {
       revert Rebalancer__InvalidProvider();
   }
   
   // Validate fee
   if (fee > assets * MAX_REBALANCE_FEE_PERCENT / PRECISION_FACTOR) {
       revert Rebalancer__ExcessRebalanceFee();
   }
   ```

2. **Withdrawal Phase**
   ```solidity
   // Withdraw from source provider
   uint256 withdrawn = from.withdraw(assets);
   ```

3. **Deposit Phase**
   ```solidity
   // Calculate amount to deposit (assets - fee)
   uint256 depositAmount = assets - fee;
   
   // Deposit to target provider
   to.deposit(depositAmount);
   ```

4. **Fee Collection**
   ```solidity
   // Transfer fee to treasury if applicable
   if (fee > 0) {
       _asset.transfer(treasury, fee);
       emit FeeCharged(treasury, assets, fee);
   }
   ```

5. **Provider Activation**
   ```solidity
   // Activate new provider if requested
   if (activateToProvider) {
       activeProvider = to;
       emit ActiveProviderUpdated(to);
   }
   ```

## Usage Examples

### Basic Rebalancing

```solidity
// Rebalance 1000 USDC from Aave to Compound
rebalancer.rebalance(
    1000e6,           // 1000 USDC
    aaveProvider,     // from Aave
    compoundProvider, // to Compound
    10e6,             // 10 USDC fee
    true              // activate Compound
);
```

### Fee-Free Rebalancing

```solidity
// Rebalance without fee
rebalancer.rebalance(
    500e6,            // 500 USDC
    compoundProvider, // from Compound
    aaveProvider,     // to Aave
    0,                // no fee
    false             // don't activate
);
```

### Emergency Rebalancing

```solidity
// Emergency rebalancing with high fee
rebalancer.rebalance(
    type(uint256).max, // all funds
    riskyProvider,     // from risky provider
    safeProvider,      // to safe provider
    100e6,             // 100 USDC fee
    true               // activate safe provider
);
```

## Security Considerations

### Fee Limitations

- Maximum rebalancing fee: 20% of rebalanced amount
- Fee is transferred to treasury immediately
- Fee calculation uses precision factor to avoid rounding errors

### Provider Validation

- Only registered providers can be used for rebalancing
- Providers must implement the `IProvider` interface
- Zero addresses are not allowed

### Access Control

- Only operators can execute rebalancing
- Admin can pause rebalancing operations
- Timelock can update provider list

## Integration with Vault

### Inheritance

Rebalancer inherits all functionality from Vault:
- ERC4626 compliance
- Deposit/withdrawal operations
- Fee management
- Provider management

### Extended Functionality

Additional features beyond Vault:
- Rebalancing between providers
- Fee collection for rebalancing
- Provider activation
- Emergency rebalancing capabilities

## Events

### RebalanceExecuted

Emitted when rebalancing is completed successfully.

```solidity
event RebalanceExecuted(
    uint256 assetsFrom,    // Amount withdrawn from source
    uint256 assetsTo,      // Amount deposited to target
    address indexed from,  // Source provider
    address indexed to     // Target provider
);
```

### FeeCharged

Emitted when rebalancing fee is collected.

```solidity
event FeeCharged(
    address indexed treasury, // Treasury address
    uint256 assets,          // Total rebalanced amount
    uint256 fee              // Fee amount
);
```

## Error Handling

### Rebalancer__InvalidProvider

Thrown when invalid providers are specified.

```solidity
error Rebalancer__InvalidProvider();
```

### Rebalancer__ExcessRebalanceFee

Thrown when rebalancing fee exceeds maximum limit.

```solidity
error Rebalancer__ExcessRebalanceFee();
```

## Constants

```solidity
uint256 internal constant MAX_REBALANCE_FEE_PERCENT = 0.2 * 1e18; // 20%
```

## Best Practices

### Fee Optimization

- Use minimal fees for regular rebalancing
- Reserve higher fees for emergency situations
- Monitor fee impact on overall yield

### Provider Selection

- Regularly assess provider performance
- Consider gas costs when rebalancing
- Maintain diversification across providers

### Monitoring

- Track rebalancing frequency
- Monitor fee collection
- Analyze yield improvements

## Testing

### Unit Tests

```solidity
function testRebalance() public {
    // Setup
    uint256 amount = 1000e6;
    
    // Execute
    rebalancer.rebalance(amount, providerA, providerB, 0, true);
    
    // Verify
    assertEq(providerB.balance(), amount);
}
```

### Integration Tests

```solidity
function testRebalanceWithFee() public {
    // Setup
    uint256 amount = 1000e6;
    uint256 fee = 50e6;
    
    // Execute
    rebalancer.rebalance(amount, providerA, providerB, fee, false);
    
    // Verify
    assertEq(providerB.balance(), amount - fee);
    assertEq(treasury.balance(), fee);
}
``` 
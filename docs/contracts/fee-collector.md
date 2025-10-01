# FeeCollector

Contract for automatic collection of protocol fees from vaults on a scheduled basis.

**File:** `contracts/FeeCollector.sol`

## Overview

FeeCollector enables automatic collection of accumulated fees from vault contracts at regular intervals. This eliminates the need for manual fee collection and ensures consistent revenue generation for the protocol.

## Key Features

- **Scheduled Collection**: Automatic fee collection at configurable intervals
- **Multi-Vault Support**: Manage multiple vaults from a single contract
- **Flexible Intervals**: Collection intervals from 1 day to 30 days
- **Batch Operations**: Collect from all ready vaults in a single transaction
- **Transparent Tracking**: Complete history of fee collections per vault

## Constructor

```solidity
constructor(address _treasury)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `_treasury` | `address` | Treasury address to collect fees to |

## Main Functions

### registerVault(address vault, uint256 collectionInterval)

Registers a vault for automatic fee collection.

```solidity
function registerVault(address vault, uint256 collectionInterval) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vault` | `address` | Vault contract address |
| `collectionInterval` | `uint256` | Collection interval in seconds (1 day - 30 days) |

#### Limitations

- Only admin can register vaults
- Vault address cannot be zero
- Collection interval must be between 1 day and 30 days

#### Events

```solidity
event VaultRegistered(address indexed vault, uint256 collectionInterval);
```

### unregisterVault(address vault)

Unregisters a vault from automatic fee collection.

```solidity
function unregisterVault(address vault) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vault` | `address` | Vault contract address to unregister |

#### Events

```solidity
event VaultUnregistered(address indexed vault);
```

### collectFees(address vault)

Collects fees from a specific vault if enough time has passed.

```solidity
function collectFees(address vault) external
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vault` | `address` | Vault address to collect fees from |

#### Process Flow

1. **Validation**: Check if vault is registered and ready for collection
2. **Balance Check**: Verify vault has fees to collect
3. **Transfer**: Move fees from vault to treasury
4. **Update**: Update vault's last collection time and total fees

#### Events

```solidity
event FeesCollected(address indexed vault, address indexed asset, uint256 amount);
```

### collectAllFees()

Collects fees from all registered vaults that are ready.

```solidity
function collectAllFees() external
```

This function iterates through all registered vaults and attempts to collect fees from those that are ready. Failed collections are skipped to prevent the entire operation from failing.

### updateCollectionInterval(address vault, uint256 newInterval)

Updates the collection interval for a specific vault.

```solidity
function updateCollectionInterval(address vault, uint256 newInterval) external onlyAdmin
```

#### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vault` | `address` | Vault contract address |
| `newInterval` | `uint256` | New collection interval in seconds |

#### Events

```solidity
event CollectionIntervalUpdated(address indexed vault, uint256 newInterval);
```

## View Functions

### getVaultInfo(address vault)

Returns detailed information about a vault's collection status.

```solidity
function getVaultInfo(address vault) external view returns (VaultInfo memory)
```

#### Returns

```solidity
struct VaultInfo {
    bool isRegistered;           // Whether vault is registered
    uint256 lastCollectionTime;  // Timestamp of last collection
    uint256 collectionInterval;  // Collection interval in seconds
    uint256 totalFeesCollected;  // Total fees collected from this vault
}
```

### isVaultReadyForCollection(address vault)

Checks if a vault is ready for fee collection.

```solidity
function isVaultReadyForCollection(address vault) external view returns (bool)
```

### getTimeUntilNextCollection(address vault)

Returns the time remaining until the next collection for a vault.

```solidity
function getTimeUntilNextCollection(address vault) external view returns (uint256)
```

### getRegisteredVaults()

Returns an array of all registered vault addresses.

```solidity
function getRegisteredVaults() external view returns (address[] memory)
```

### getRegisteredVaultsCount()

Returns the number of registered vaults.

```solidity
function getRegisteredVaultsCount() external view returns (uint256)
```

## Configuration

### setTreasury(address _treasury)

Updates the treasury address for fee collection.

```solidity
function setTreasury(address _treasury) external onlyAdmin
```

#### Events

```solidity
event TreasuryUpdated(address indexed newTreasury);
```

## Constants

```solidity
uint256 public constant MIN_COLLECTION_INTERVAL = 1 days;   // 1 day
uint256 public constant MAX_COLLECTION_INTERVAL = 30 days;  // 30 days
```

## Error Handling

### FeeCollector__InvalidVault

Thrown when vault address is zero or vault is not registered.

```solidity
error FeeCollector__InvalidVault();
```

### FeeCollector__InvalidInterval

Thrown when collection interval is outside allowed range.

```solidity
error FeeCollector__InvalidInterval();
```

### FeeCollector__NotEnoughTimePassed

Thrown when trying to collect fees before the interval has passed.

```solidity
error FeeCollector__NotEnoughTimePassed();
```

### FeeCollector__NoFeesToCollect

Thrown when vault has no fees to collect.

```solidity
error FeeCollector__NoFeesToCollect();
```

## Usage Examples

### Basic Setup

```solidity
// Deploy FeeCollector
FeeCollector feeCollector = new FeeCollector(treasuryAddress);

// Register a vault for weekly collection
feeCollector.registerVault(vaultAddress, 7 days);

// Check if ready for collection
bool ready = feeCollector.isVaultReadyForCollection(vaultAddress);

// Collect fees if ready
if (ready) {
    feeCollector.collectFees(vaultAddress);
}
```

### Batch Collection

```solidity
// Collect from all ready vaults
feeCollector.collectAllFees();
```

### Monitoring

```solidity
// Get vault information
VaultInfo memory info = feeCollector.getVaultInfo(vaultAddress);
console.log("Total fees collected:", info.totalFeesCollected);
console.log("Last collection:", info.lastCollectionTime);

// Check time until next collection
uint256 timeLeft = feeCollector.getTimeUntilNextCollection(vaultAddress);
console.log("Hours until next collection:", timeLeft / 3600);
```

## Integration with Vaults

### Fee Accumulation

Vaults accumulate fees in their contract balance through:
- Rebalancing operations with fees
- Withdrawal fees (if configured)
- Any other fee-generating operations

### Fee Collection Process

1. **Vault Balance**: Fees accumulate in vault's asset balance
2. **Time Check**: FeeCollector checks if enough time has passed
3. **Transfer**: Fees are transferred from vault to treasury
4. **Tracking**: Collection is recorded and timestamped

## Security Considerations

### Access Control

- **Admin Role**: Required for vault registration and configuration
- **Public Collection**: Anyone can trigger fee collection (incentivizes automation)
- **Treasury Security**: Treasury address can only be changed by admin

### Time-based Security

- **Minimum Interval**: Prevents excessive fee collection
- **Maximum Interval**: Ensures regular fee collection
- **Timestamp Validation**: Prevents manipulation of collection timing

### Error Handling

- **Graceful Failures**: Individual vault failures don't affect others
- **Balance Validation**: Ensures fees exist before collection
- **State Consistency**: Maintains accurate tracking of collections

## Deployment and Setup

### 1. Deploy FeeCollector

```bash
npx hardhat run deploy/deploy-fee-collector.ts --network <network>
```

### 2. Register Vaults

```bash
# Set environment variables
export FEE_COLLECTOR_ADDRESS=<deployed_address>
export VAULT_ADDRESS=<vault_address>
export COLLECTION_INTERVAL=604800  # 7 days

# Register vault
npx hardhat run scripts/setup-fee-collection.ts --network <network>
```

### 3. Monitor and Collect

```bash
# Check all vaults status
npx hardhat run scripts/setup-fee-collection.ts check-all --network <network>

# Collect from all ready vaults
npx hardhat run scripts/setup-fee-collection.ts collect-all --network <network>
```

## Best Practices

### Interval Selection

- **Weekly (7 days)**: Good balance for most protocols
- **Daily (1 day)**: For high-volume protocols
- **Monthly (30 days)**: For low-volume protocols

### Monitoring

- **Regular Checks**: Monitor vault balances and collection status
- **Automation**: Use scripts or bots for regular collection
- **Alerts**: Set up notifications for failed collections

### Treasury Management

- **Secure Storage**: Use multisig or timelock for treasury
- **Regular Transfers**: Move collected fees to secure storage
- **Transparency**: Publish collection reports for transparency

This FeeCollector provides a robust, automated solution for protocol fee collection while maintaining security and transparency.


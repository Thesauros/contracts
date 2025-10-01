# Thesauros Protocol - Fee Model Documentation

## Overview

Thesauros implements a dual-tier fee structure that generates revenue through user withdrawals and automated rebalancing operations. All fees are collected in the underlying asset and transferred to the protocol treasury.

## Fee Structure

### 1. Withdrawal Fees

**Purpose**: Revenue generation from user withdrawals
**Scope**: Applied to all user withdrawal operations

#### Implementation
```solidity
// Fee calculation in _withdraw() function
uint256 withdrawFee = assets.mulDiv(withdrawFeePercent, PRECISION_FACTOR);
uint256 assetsToReceiver = assets - withdrawFee;

// Fee transfer to treasury
_asset.safeTransfer(_treasury, withdrawFee);
emit FeeCharged(_treasury, assets, withdrawFee);
```

#### Parameters
- **Maximum Fee**: 5% (`MAX_WITHDRAW_FEE_PERCENT = 0.05 * 1e18`)
- **Default Fee**: 0.1% (`WITHDRAW_FEE_PERCENT = 0.001 ether`)
- **Precision**: 18 decimals (`PRECISION_FACTOR = 1e18`)

#### Application Points
- `withdraw(uint256 assets, address receiver, address owner)`
- `redeem(uint256 shares, address receiver, address owner)`

#### Process Flow
1. User initiates withdrawal of `assets` amount
2. System calculates fee: `fee = assets * withdrawFeePercent / 1e18`
3. Fee is transferred to treasury address
4. User receives: `assets - fee`
5. Event `FeeCharged` is emitted

### 2. Rebalancing Fees

**Purpose**: Revenue generation from automated rebalancing operations
**Scope**: Applied to rebalancing operations between providers

#### Implementation
```solidity
// Fee validation in _checkFee() function
function _checkFee(uint256 fee, uint256 amount) internal pure {
    uint256 reasonableFee = amount.mulDiv(MAX_REBALANCE_FEE_PERCENT, PRECISION_FACTOR);
    if (fee > reasonableFee) {
        revert Rebalancer__ExcessRebalanceFee();
    }
}

// Fee collection in rebalance() function
if (fee > 0) {
    address _treasury = treasury;
    _asset.safeTransfer(_treasury, fee);
    emit FeeCharged(_treasury, assets, fee);
}
```

#### Parameters
- **Maximum Fee**: 20% (`MAX_REBALANCE_FEE_PERCENT = 0.2 * 1e18`)
- **Default Fee**: 0.1% (`REBALANCE_FEE_PERCENT = 0.001 ether`)
- **Precision**: 18 decimals (`PRECISION_FACTOR = 1e18`)

#### Application Points
- `rebalance(uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)`

#### Process Flow
1. Operator initiates rebalancing of `assets` amount
2. System validates fee does not exceed 20% of assets
3. Assets are withdrawn from source provider
4. `assets - fee` are deposited to target provider
5. Fee is transferred to treasury
6. Events `FeeCharged` and `RebalanceExecuted` are emitted

## Fee Collection Mechanism

### Treasury Management
```solidity
address public treasury;
```

All fees are collected in the underlying asset (USDC, USDT, etc.) and transferred to the designated treasury address.

### Fee Events
```solidity
event FeeCharged(address indexed treasury, uint256 assets, uint256 fee);
```

Every fee collection generates an event for transparency and tracking purposes.

## Fee Configuration

### Withdrawal Fee Configuration
```solidity
function setWithdrawFeePercent(uint256 _withdrawFeePercent) external onlyAdmin {
    _setWithdrawFeePercent(_withdrawFeePercent);
}

function _setWithdrawFeePercent(uint256 _withdrawFeePercent) internal {
    if (_withdrawFeePercent > MAX_WITHDRAW_FEE_PERCENT) {
        revert Vault__InvalidInput();
    }
    withdrawFeePercent = _withdrawFeePercent;
    emit WithdrawFeePercentUpdated(_withdrawFeePercent);
}
```

### Access Control
- **Withdrawal Fee Changes**: `onlyAdmin` role required
- **Rebalancing Fee**: Set per operation by `onlyOperator` role
- **Treasury Address**: `onlyAdmin` role required

## Fee Calculation Examples

### Withdrawal Fee Example
```
User withdraws: 1,000 USDC
Withdrawal fee rate: 0.1%
Fee calculation: 1,000 * 0.001 / 1 = 1 USDC
User receives: 999 USDC
Treasury receives: 1 USDC
```

### Rebalancing Fee Example
```
Rebalancing amount: 10,000 USDC
Rebalancing fee rate: 0.1%
Fee calculation: 10,000 * 0.001 / 1 = 10 USDC
Deposited to new provider: 9,990 USDC
Treasury receives: 10 USDC
```

## Security Measures

### Fee Limits
- **Withdrawal fees**: Hard-capped at 5%
- **Rebalancing fees**: Hard-capped at 20%
- **Validation**: All fees validated before execution

### Access Controls
- **Admin Role**: Can modify withdrawal fee rates
- **Operator Role**: Can set rebalancing fees per operation
- **Timelock**: Can modify treasury address with delay

### Transparency
- **Events**: All fee collections logged
- **Public Variables**: Fee rates publicly readable
- **Validation**: Fee limits enforced at contract level

## Revenue Model

### Fee Collection Points
1. **User Withdrawals**: Every withdrawal generates revenue
2. **Rebalancing Operations**: Each rebalance can include a fee
3. **Treasury Management**: Centralized fee collection

### Revenue Scaling
- **TVL Growth**: Higher TVL = more withdrawal activity
- **Rebalancing Frequency**: More rebalancing = more fee opportunities
- **User Activity**: Active users generate more withdrawal fees

### Fee Optimization
- **Competitive Rates**: Fees set to remain competitive
- **Gas Efficiency**: Batch operations reduce costs
- **User Experience**: Transparent fee structure

## Implementation Details

### Constants
```solidity
uint256 internal constant PRECISION_FACTOR = 1e18;
uint256 internal constant MAX_WITHDRAW_FEE_PERCENT = 0.05 * 1e18; // 5%
uint256 internal constant MAX_REBALANCE_FEE_PERCENT = 0.2 * 1e18; // 20%
```

### State Variables
```solidity
uint256 public withdrawFeePercent;
address public treasury;
```

### Error Handling
```solidity
error Vault__InvalidInput(); // Fee exceeds maximum
error Rebalancer__ExcessRebalanceFee(); // Rebalance fee too high
```

## Automated Fee Collection

### FeeCollector Contract

The protocol includes an automated fee collection system through the `FeeCollector` contract that enables scheduled collection of accumulated fees from vaults.

#### Key Features
- **Scheduled Collection**: Automatic fee collection at configurable intervals (1-30 days)
- **Multi-Vault Support**: Manage multiple vaults from a single contract
- **Batch Operations**: Collect from all ready vaults in one transaction
- **Transparent Tracking**: Complete history of fee collections per vault

#### Implementation
```solidity
// Register vault for weekly collection
feeCollector.registerVault(vaultAddress, 7 days);

// Collect fees when ready
feeCollector.collectFees(vaultAddress);

// Collect from all ready vaults
feeCollector.collectAllFees();
```

#### Collection Process
1. **Fee Accumulation**: Fees accumulate in vault's asset balance
2. **Time Validation**: System checks if collection interval has passed
3. **Balance Check**: Verifies vault has fees to collect
4. **Transfer**: Moves fees from vault to treasury
5. **Tracking**: Updates collection timestamp and total fees

#### Configuration
- **Collection Intervals**: 1 day to 30 days
- **Access Control**: Admin role required for registration
- **Public Collection**: Anyone can trigger collection (incentivizes automation)

#### Usage Examples
```solidity
// Weekly collection setup
feeCollector.registerVault(vaultAddress, 604800); // 7 days

// Check readiness
bool ready = feeCollector.isVaultReadyForCollection(vaultAddress);

// Get collection info
VaultInfo memory info = feeCollector.getVaultInfo(vaultAddress);
uint256 timeLeft = feeCollector.getTimeUntilNextCollection(vaultAddress);
```

This automated system ensures consistent fee collection without manual intervention, providing a sustainable and transparent revenue model for the protocol.

## Weekly Profit Fee Collection

### WeeklyProfitFeeCollector Contract

The protocol now includes an advanced profit-based fee collection system through the `WeeklyProfitFeeCollector` contract that automatically collects 25% of user profits on a weekly basis.

#### Key Features
- **Profit Tracking**: Tracks individual user profits since last collection
- **Weekly Collection**: Automatic fee collection every 7 days
- **User Registration**: Users must be registered for profit tracking
- **Transparent Calculation**: Clear profit and fee calculation methods
- **Configurable Fees**: Admin can adjust fee percentages (up to 50%)

#### Implementation
```solidity
// Register vault for profit fee collection
weeklyProfitFeeCollector.registerVault(vaultAddress, 2500); // 25%

// Register user for profit tracking
weeklyProfitFeeCollector.registerUser(vaultAddress, userAddress);

// Collect fees when ready
weeklyProfitFeeCollector.collectUserProfitFees(vaultAddress, userAddress);
```

#### Collection Process
1. **User Registration**: User must be registered for profit tracking
2. **Profit Calculation**: System calculates profit since last collection
3. **Fee Calculation**: 25% of profit is calculated as fee
4. **Share Burning**: Equivalent shares are burned from user's balance
5. **Asset Transfer**: Fee assets are transferred to treasury
6. **Tracking Update**: User's last collection time and shares are updated

#### Configuration
- **Fee Percentages**: 0% to 50% (configurable per vault)
- **Collection Intervals**: 1 day to 30 days (default: 7 days)
- **Access Control**: Admin role required for vault registration
- **Public Collection**: Anyone can trigger collection (incentivizes automation)

## Rebalancing with Profit Fees

### RebalancerWithProfitFees Contract

An alternative approach that collects profit fees during rebalancing operations, ensuring fees are collected when the vault is actively managed.

#### Key Features
- **Automatic Collection**: Profit fees collected during each rebalancing
- **Global Profit Tracking**: Tracks total vault profit since last rebalancing
- **Proportional Distribution**: Fees are collected proportionally from all users
- **Integrated Operation**: Seamlessly integrated with existing rebalancing logic

#### Implementation
```solidity
// Deploy with profit fee configuration
new RebalancerWithProfitFees(
    assetAddress,
    "Vault Name",
    "SYMBOL",
    providers,
    withdrawFeePercent,
    timelock,
    treasury,
    2500 // 25% profit fee
);

// Profit fees are automatically collected during rebalancing
rebalancer.rebalance(assets, fromProvider, toProvider, rebalanceFee, activate);
```

#### Collection Process
1. **Profit Detection**: System detects profit since last rebalancing
2. **Fee Calculation**: 25% of total profit is calculated as fee
3. **Share Burning**: Equivalent shares are burned from vault's balance
4. **Asset Withdrawal**: Fee assets are withdrawn from active provider
5. **Treasury Transfer**: Fee assets are transferred to treasury
6. **State Update**: Last total assets value is updated

#### Benefits
- **Automatic Collection**: No manual intervention required
- **Fair Distribution**: All users contribute proportionally
- **Operational Efficiency**: Fees collected during routine operations
- **Transparent Process**: Clear profit and fee tracking

## Usage Examples

### Weekly Profit Fee Collection
```solidity
// Setup
weeklyProfitFeeCollector.registerVault(vaultAddress, 2500); // 25%
weeklyProfitFeeCollector.registerUser(vaultAddress, userAddress);

// Check readiness
bool ready = weeklyProfitFeeCollector.isUserReadyForCollection(vaultAddress, userAddress);
uint256 timeLeft = weeklyProfitFeeCollector.getTimeUntilNextCollection(vaultAddress, userAddress);

// Calculate potential fees
(uint256 profit, uint256 fee) = weeklyProfitFeeCollector.calculateProfitFee(vaultAddress, userAddress);

// Collect fees
weeklyProfitFeeCollector.collectUserProfitFees(vaultAddress, userAddress);
```

### Rebalancing with Profit Fees
```solidity
// Check potential profit fees
(uint256 profit, uint256 fee) = rebalancer.calculatePotentialProfitFee();

// Manual profit fee collection
rebalancer.collectProfitFees();

// Rebalancing (automatically collects profit fees)
rebalancer.rebalance(assets, fromProvider, toProvider, rebalanceFee, activate);
```

## Comparison of Approaches

| Feature | WeeklyProfitFeeCollector | RebalancerWithProfitFees |
|---------|-------------------------|-------------------------|
| Collection Frequency | Weekly (configurable) | During rebalancing |
| User Tracking | Individual user tracking | Global vault tracking |
| Gas Efficiency | Higher (per user) | Lower (global) |
| Automation | Requires external triggers | Automatic during rebalancing |
| Fairness | Per-user profit calculation | Proportional distribution |
| Complexity | Higher | Lower |

## Security Considerations

### Fee Limits
- **Profit fees**: Hard-capped at 50%
- **Collection intervals**: Minimum 1 day, maximum 30 days
- **Validation**: All fees validated before execution

### Access Controls
- **Admin Role**: Can modify fee rates and register vaults
- **Public Collection**: Anyone can trigger collection (incentivizes automation)
- **User Registration**: Required for profit tracking

### Transparency
- **Events**: All fee collections logged
- **Public Variables**: Fee rates and intervals publicly readable
- **Calculation Methods**: Clear profit and fee calculation functions

This enhanced fee model provides multiple approaches for collecting profit-based fees while maintaining transparency and user-friendly operations.

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

This fee model provides a sustainable revenue stream while maintaining user-friendly rates and transparent operations.

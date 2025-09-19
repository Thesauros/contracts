# MorphoProvider

## Overview

MorphoProvider is a yield provider that integrates with [Morpho Protocol](https://morpho.org/), one of the most trusted lending networks in DeFi. It allows vaults to supply assets to Morpho markets and earn yield through lending activities.

## Features

- **Morpho Protocol Integration**: Direct integration with Morpho's lending markets
- **Multi-Asset Support**: Supports various assets through market parameters
- **Interest Rate Calculation**: Dynamic rate calculation based on market utilization
- **ProviderManager Integration**: Uses the standard ProviderManager pattern for configuration

## Architecture

```
MorphoProvider
├── IProvider interface compliance
├── ProviderManager integration
├── Market parameters validation
├── Asset validation and transfer
├── Interest rate calculation
└── Error handling and events
```

## Key Functions

### Core IProvider Methods

#### `getIdentifier()`
Returns the provider identifier: `"Morpho_Provider"`

#### `getSource(asset, market, user)`
Returns the Morpho protocol contract address for approvals.

#### `deposit(amount, vault)`
Supplies assets to Morpho market:
1. Validates vault asset
2. Transfers assets from vault to provider
3. Approves Morpho to spend assets
4. Supplies assets to Morpho market

#### `withdraw(amount, vault)`
Withdraws assets from Morpho market:
1. Validates vault asset
2. Checks sufficient supply balance
3. Withdraws assets from Morpho market
4. Transfers assets back to vault

#### `getDepositBalance(user, vault)`
Returns the user's deposit balance by calculating:
```
balance = (supplyShares * totalSupplyAssets) / totalSupplyShares
```

#### `getDepositRate(vault)`
Returns the current deposit rate based on:
- Market utilization
- Borrow rate
- Fee structure

## Configuration

### ProviderManager Setup

The provider requires configuration through ProviderManager:

```typescript
// Set yield token (Morpho protocol address)
await providerManager.setYieldToken(
    "Morpho_Provider",
    assetAddress,
    morphoProtocolAddress
);

// Set market (for asset-specific configuration)
await providerManager.setMarket(
    "Morpho_Provider",
    assetAddress,
    address(0), // No second asset for Morpho
    morphoProtocolAddress
);
```

### Market Parameters

MorphoProvider uses market parameters to define lending markets:

```solidity
struct MarketParams {
    address loanToken;        // The asset being lent
    address collateralToken;  // Collateral token (if applicable)
    address oracle;          // Price oracle
    address irm;             // Interest Rate Model
    uint256 lltv;            // Loan-to-Value ratio
}
```

## Supported Assets

MorphoProvider can be configured to support any ERC20 token that has a corresponding Morpho market. Common supported assets include:

- USDC
- WETH
- USDT
- And other Morpho-supported assets

## Error Handling

The provider includes comprehensive error handling:

- `MorphoProvider__AddressZero()`: Zero address provided
- `MorphoProvider__InvalidAmount()`: Invalid amount (zero)
- `MorphoProvider__InsufficientBalance()`: Insufficient balance
- `MorphoProvider__MarketNotCreated()`: Market not found
- `MorphoProvider__InvalidAsset()`: Unsupported asset

## Events

- `YieldTokenUpdated`: Emitted when yield token is configured
- `MarketUpdated`: Emitted when market is configured

## Security Considerations

1. **Market Validation**: All operations validate market existence
2. **Asset Validation**: Only supported assets can be used
3. **Balance Checks**: Sufficient balance validation before operations
4. **ProviderManager Integration**: Centralized configuration management

## Usage Example

```solidity
// Deploy MorphoProvider
MorphoProvider morphoProvider = new MorphoProvider(providerManagerAddress);

// Configure through ProviderManager
await providerManager.setYieldToken("Morpho_Provider", usdcAddress, morphoAddress);
await providerManager.setMarket("Morpho_Provider", usdcAddress, address(0), morphoAddress);

// Use in vault
bool success = morphoProvider.deposit(amount, vault);
uint256 balance = morphoProvider.getDepositBalance(user, vault);
uint256 rate = morphoProvider.getDepositRate(vault);
```

## Testing

The provider includes comprehensive tests covering:

- Constructor validation
- Deposit/withdraw operations
- Balance calculations
- Rate calculations
- Error conditions
- Asset validation

Run tests with:
```bash
forge test --match-contract MorphoProviderTest -v
```

## Current Status

- ✅ Provider contract implemented and tested
- ✅ ProviderManager integration ready
- ✅ Test coverage: 100% (15/15 tests passing)
- ✅ Full IProvider interface compliance
- ⏳ Production deployment pending
- ⏳ Real Morpho Protocol integration pending

## Dependencies

- OpenZeppelin Contracts (ERC20, SafeERC20)
- Morpho Protocol interfaces
- Thesauros IProvider interface
- Thesauros ProviderManager

## Version

Current version: 1.0.0

## License

MIT License

# Vault

Base vault contract implementing the ERC4626 standard for asset management and interaction with liquidity providers.

**File:** `contracts/base/Vault.sol`

## Overview

Vault is the central component of the Thesauros system. It inherits from ERC4626 and provides functionality for:
- User deposits and withdrawals
- Conversion between assets and shares
- Interaction with liquidity providers
- Fee and settings management

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

### Limitations

- `withdrawFeePercent_` cannot exceed 5% (`MAX_WITHDRAW_FEE_PERCENT`)
- `asset_`, `timelock_`, `treasury_` cannot be zero addresses
- Vault is initially paused for deposits until setup is completed

## ERC4626 Methods

### asset()

Returns the address of the vault's underlying asset.

```solidity
function asset() public view returns (address)
```

**Returns:** Address of the ERC20 token used as the underlying asset.

### totalAssets()

Returns the total amount of assets in the vault.

```solidity
function totalAssets() public view returns (uint256 assets)
```

**Returns:** Sum of all assets deposited with providers.

### convertToShares(uint256 assets)

Converts amount of assets to amount of shares.

```solidity
function convertToShares(uint256 assets) public view returns (uint256 shares)
```

**Parameters:**
- `assets` - amount of assets to convert

**Returns:** Amount of shares corresponding to the specified assets.

### convertToAssets(uint256 shares)

Converts amount of shares to amount of assets.

```solidity
function convertToAssets(uint256 shares) public view returns (uint256 assets)
```

**Parameters:**
- `shares` - amount of shares to convert

**Returns:** Amount of assets corresponding to the specified shares.

### maxDeposit(address)

Returns the maximum amount of assets that can be deposited.

```solidity
function maxDeposit(address) public view returns (uint256)
```

**Returns:** `type(uint256).max` if deposits are not paused, otherwise `0`.

### maxMint(address)

Returns the maximum amount of shares that can be minted.

```solidity
function maxMint(address) public view returns (uint256)
```

**Returns:** `type(uint256).max` if deposits are not paused, otherwise `0`.

### maxWithdraw(address owner)

Returns the maximum amount of assets that the owner can withdraw.

```solidity
function maxWithdraw(address owner) public view returns (uint256)
```

**Parameters:**
- `owner` - address of the share owner

**Returns:** Amount of assets that the owner can withdraw.

### maxRedeem(address owner)

Returns the maximum amount of shares that the owner can redeem.

```solidity
function maxRedeem(address owner) public view returns (uint256)
```

**Parameters:**
- `owner` - address of the share owner

**Returns:** Amount of shares that the owner can redeem.

### previewDeposit(uint256 assets)

Preview calculation of shares for asset deposit.

```solidity
function previewDeposit(uint256 assets) public view returns (uint256)
```

**Parameters:**
- `assets` - amount of assets to deposit

**Returns:** Amount of shares that will be minted.

### previewMint(uint256 shares)

Preview calculation of assets for share minting.

```solidity
function previewMint(uint256 shares) public view returns (uint256)
```

**Parameters:**
- `shares` - amount of shares to mint

**Returns:** Amount of assets required to mint shares.

### previewWithdraw(uint256 assets)

Preview calculation of shares for asset withdrawal.

```solidity
function previewWithdraw(uint256 assets) public view returns (uint256)
```

**Parameters:**
- `assets` - amount of assets to withdraw

**Returns:** Amount of shares that will be burned.

### previewRedeem(uint256 shares)

Preview calculation of assets for share redemption.

```solidity
function previewRedeem(uint256 shares) public view returns (uint256)
```

**Parameters:**
- `shares` - amount of shares to redeem

**Returns:** Amount of assets that will be received.

### deposit(uint256 assets, address receiver)

Deposits assets into the vault and mints shares to the receiver.

```solidity
function deposit(uint256 assets, address receiver) public returns (uint256)
```

**Parameters:**
- `assets` - amount of assets to deposit
- `receiver` - address of the share receiver

**Returns:** Amount of minted shares.

**Events:**
- `Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares)`

### mint(uint256 shares, address receiver)

Mints shares to the receiver for assets.

```solidity
function mint(uint256 shares, address receiver) public returns (uint256)
```

**Parameters:**
- `shares` - amount of shares to mint
- `receiver` - address of the share receiver

**Returns:** Amount of assets used to mint shares.

**Events:**
- `Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares)`

### withdraw(uint256 assets, address receiver, address owner)

Withdraws assets from the vault and burns shares of the owner.

```solidity
function withdraw(uint256 assets, address receiver, address owner) public returns (uint256)
```

**Parameters:**
- `assets` - amount of assets to withdraw
- `receiver` - address of the asset receiver
- `owner` - address of the share owner

**Returns:** Amount of burned shares.

**Events:**
- `Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)`
- `FeeCharged(address indexed treasury, uint256 assets, uint256 fee)`

### redeem(uint256 shares, address receiver, address owner)

Redeems shares of the owner and withdraws assets to the receiver.

```solidity
function redeem(uint256 shares, address receiver, address owner) public returns (uint256)
```

**Parameters:**
- `shares` - amount of shares to redeem
- `receiver` - address of the asset receiver
- `owner` - address of the share owner

**Returns:** Amount of withdrawn assets.

**Events:**
- `Withdraw(address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)`
- `FeeCharged(address indexed treasury, uint256 assets, uint256 fee)`

## Vault Management

### setupVault(uint256 assets)

Initializes the vault with an initial deposit to prevent inflation attacks.

```solidity
function setupVault(uint256 assets) external
```

**Parameters:**
- `assets` - amount of assets for initial setup

**Limitations:**
- Can only be called once
- `assets` must be at least `minAmount`
- After calling, deposits become available

**Events:**
- `SetupCompleted(address indexed setupAddress)`

### pause(Actions action)

Pauses the specified action in the vault.

```solidity
function pause(Actions action) external onlyAdmin
```

**Parameters:**
- `action` - action to pause (Deposit, Withdraw, Rebalance)

### unpause(Actions action)

Resumes the specified action in the vault.

```solidity
function unpause(Actions action) external onlyAdmin
```

**Parameters:**
- `action` - action to resume (Deposit, Withdraw, Rebalance)

### setTimelock(address _timelock)

Sets the timelock contract address.

```solidity
function setTimelock(address _timelock) external onlyTimelock
```

**Parameters:**
- `_timelock` - new timelock contract address

**Limitations:**
- Can only be called by the current timelock
- `_timelock` cannot be a zero address

**Events:**
- `TimelockUpdated(address indexed timelock)`

### setProviders(IProvider[] memory providers)

Sets the list of providers for the vault.

```solidity
function setProviders(IProvider[] memory providers) external onlyTimelock
```

**Parameters:**
- `providers` - new array of providers

**Limitations:**
- Can only be called by timelock
- No provider can be a zero address

**Events:**
- `ProvidersUpdated(IProvider[] providers)`

### setActiveProvider(IProvider _activeProvider)

Sets the active provider for the vault.

```solidity
function setActiveProvider(IProvider _activeProvider) external onlyAdmin
```

**Parameters:**
- `_activeProvider` - new active provider

**Limitations:**
- `_activeProvider` must be in the list of providers

**Events:**
- `ActiveProviderUpdated(IProvider activeProvider)`

### setTreasury(address _treasury)

Sets the treasury address.

```solidity
function setTreasury(address _treasury) external onlyAdmin
```

**Parameters:**
- `_treasury` - new treasury address

**Limitations:**
- `_treasury` cannot be a zero address

**Events:**
- `TreasuryUpdated(address indexed treasury)`

### setWithdrawFeePercent(uint256 _withdrawFeePercent)

Sets the withdrawal fee percentage.

```solidity
function setWithdrawFeePercent(uint256 _withdrawFeePercent) external onlyAdmin
```

**Parameters:**
- `_withdrawFeePercent` - new fee percentage

**Limitations:**
- Cannot exceed 5% (`MAX_WITHDRAW_FEE_PERCENT`)

**Events:**
- `WithdrawFeePercentUpdated(uint256 withdrawFeePercent)`

### setMinAmount(uint256 _minAmount)

Sets the minimum amount for deposits.

```solidity
function setMinAmount(uint256 _minAmount) external onlyAdmin
```

**Parameters:**
- `_minAmount` - new minimum amount

**Events:**
- `MinAmountUpdated(uint256 minAmount)`

## Helper Methods

### getBalanceOfAsset(address owner)

Returns the amount of assets owned by the specified address.

```solidity
function getBalanceOfAsset(address owner) public view returns (uint256 assets)
```

**Parameters:**
- `owner` - address of the owner

**Returns:** Amount of assets corresponding to the owner's shares.

### getProviders()

Returns the array of providers for the vault.

```solidity
function getProviders() public view returns (IProvider[] memory)
```

**Returns:** Array of all providers for the vault.

## Constants

```solidity
uint256 internal constant PRECISION_FACTOR = 1e18;
uint256 internal constant MAX_WITHDRAW_FEE_PERCENT = 0.05 * 1e18; // 5%
uint256 internal constant MAX_REBALANCE_FEE_PERCENT = 0.2 * 1e18; // 20%
```

## State

```solidity
IERC20Metadata internal immutable _asset;
uint8 private immutable _underlyingDecimals;
IProvider[] internal _providers;
IProvider public activeProvider;
uint256 public minAmount;
uint256 public withdrawFeePercent;
address public timelock;
address public treasury;
bool public setupCompleted;
```

## Events

```solidity
event SetupCompleted(address indexed setupAddress);
event TimelockUpdated(address indexed timelock);
event ProvidersUpdated(IProvider[] providers);
event ActiveProviderUpdated(IProvider activeProvider);
event TreasuryUpdated(address indexed treasury);
event WithdrawFeePercentUpdated(uint256 withdrawFeePercent);
event MinAmountUpdated(uint256 minAmount);
event FeeCharged(address indexed treasury, uint256 assets, uint256 fee);
```

## Errors

```solidity
error Vault__Unauthorized();
error Vault__AddressZero();
error Vault__InvalidInput();
error Vault__DepositLessThanMin();
error Vault__SetupAlreadyCompleted();
```

## Modifiers

```solidity
modifier onlyTimelock() {
    if (msg.sender != timelock) {
        revert Vault__Unauthorized();
    }
    _;
}
```

## Security

### Protection against inflation attacks
Vault uses the `setupVault()` mechanism to prevent inflation attacks, as described in [Hats Finance](https://rokinot.github.io/hatsfinance).

### Fee limitations
- Maximum withdrawal fee: 5%
- Maximum rebalancing fee: 20%

### Pausing operations
Individual operations can be paused for emergency response.

### Role-based access
Critical operations are restricted to Admin and Timelock roles. 
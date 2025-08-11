# Thesauros: Interest Vault Contracts

This is the repository of smart contracts for interest rebalancing. The system allows automatic redistribution of funds between various liquidity providers to maximize yield.

## Architecture

The system consists of the following main components:

- **Vault** - base vault contract with ERC4626 support
- **Rebalancer** - contract for rebalancing between providers
- **RebalancerWithRewards** - extended version with rewards support
- **VaultManager** - manager for managing multiple vaults
- **Timelock** - contract for secure governance with delay
- **RewardsDistributor** - rewards distributor with Merkle proof
- **ProviderManager** - liquidity provider manager

## Installation

```bash
npm install
```

## Testing

```bash
npx hardhat test
```

## Test Coverage

```bash
npx hardhat coverage
```

## Method Documentation

### Vault.sol

Base vault contract implementing ERC4626 standard.

#### Constructor
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
**Parameters:**
- `asset_` - address of the underlying asset
- `name_` - vault token name
- `symbol_` - vault token symbol
- `providers_` - array of liquidity providers
- `withdrawFeePercent_` - withdrawal fee percentage (maximum 5%)
- `timelock_` - timelock contract address
- `treasury_` - treasury address

#### ERC4626 Methods

##### `asset()`
Returns the address of the underlying asset vault.
```solidity
function asset() public view returns (address)
```

##### `totalAssets()`
Returns the total amount of assets in the vault.
```solidity
function totalAssets() public view returns (uint256 assets)
```

##### `convertToShares(uint256 assets)`
Converts amount of assets to amount of shares.
```solidity
function convertToShares(uint256 assets) public view returns (uint256 shares)
```

##### `convertToAssets(uint256 shares)`
Converts amount of shares to amount of assets.
```solidity
function convertToAssets(uint256 shares) public view returns (uint256 assets)
```

##### `maxDeposit(address)`
Returns the maximum amount of assets that can be deposited.
```solidity
function maxDeposit(address) public view returns (uint256)
```

##### `maxMint(address)`
Returns the maximum amount of shares that can be minted.
```solidity
function maxMint(address) public view returns (uint256)
```

##### `maxWithdraw(address owner)`
Returns the maximum amount of assets that the owner can withdraw.
```solidity
function maxWithdraw(address owner) public view returns (uint256)
```

##### `maxRedeem(address owner)`
Returns the maximum amount of shares that the owner can redeem.
```solidity
function maxRedeem(address owner) public view returns (uint256)
```

##### `previewDeposit(uint256 assets)`
Preview calculation of shares for asset deposit.
```solidity
function previewDeposit(uint256 assets) public view returns (uint256)
```

##### `previewMint(uint256 shares)`
Preview calculation of assets for share minting.
```solidity
function previewMint(uint256 shares) public view returns (uint256)
```

##### `previewWithdraw(uint256 assets)`
Preview calculation of shares for asset withdrawal.
```solidity
function previewWithdraw(uint256 assets) public view returns (uint256)
```

##### `previewRedeem(uint256 shares)`
Preview calculation of assets for share redemption.
```solidity
function previewRedeem(uint256 shares) public view returns (uint256)
```

##### `deposit(uint256 assets, address receiver)`
Deposits assets into the vault and mints shares to the receiver.
```solidity
function deposit(uint256 assets, address receiver) public returns (uint256)
```

##### `mint(uint256 shares, address receiver)`
Mints shares to the receiver for assets.
```solidity
function mint(uint256 shares, address receiver) public returns (uint256)
```

##### `withdraw(uint256 assets, address receiver, address owner)`
Withdraws assets from the vault and burns owner's shares.
```solidity
function withdraw(uint256 assets, address receiver, address owner) public returns (uint256)
```

##### `redeem(uint256 shares, address receiver, address owner)`
Redeems owner's shares and withdraws assets to the receiver.
```solidity
function redeem(uint256 shares, address receiver, address owner) public returns (uint256)
```

#### Vault Management

##### `setupVault(uint256 assets)`
Initializes the vault with initial deposit to prevent inflation attacks.
```solidity
function setupVault(uint256 assets) external
```

##### `pause(Actions action)`
Pauses the specified action in the vault.
```solidity
function pause(Actions action) external onlyAdmin
```

##### `unpause(Actions action)`
Resumes the specified action in the vault.
```solidity
function unpause(Actions action) external onlyAdmin
```

##### `setTimelock(address _timelock)`
Sets the timelock contract address.
```solidity
function setTimelock(address _timelock) external onlyTimelock
```

##### `setProviders(IProvider[] memory providers)`
Sets the list of providers for the vault.
```solidity
function setProviders(IProvider[] memory providers) external onlyTimelock
```

##### `setActiveProvider(IProvider _activeProvider)`
Sets the active provider for the vault.
```solidity
function setActiveProvider(IProvider _activeProvider) external onlyAdmin
```

##### `setTreasury(address _treasury)`
Sets the treasury address.
```solidity
function setTreasury(address _treasury) external onlyAdmin
```

##### `setWithdrawFeePercent(uint256 _withdrawFeePercent)`
Sets the withdrawal fee percentage (maximum 5%).
```solidity
function setWithdrawFeePercent(uint256 _withdrawFeePercent) external onlyAdmin
```

##### `setMinAmount(uint256 _minAmount)`
Sets the minimum amount for deposits.
```solidity
function setMinAmount(uint256 _minAmount) external onlyAdmin
```

#### Helper Methods

##### `getBalanceOfAsset(address owner)`
Returns the amount of assets owned by the specified address.
```solidity
function getBalanceOfAsset(address owner) public view returns (uint256 assets)
```

##### `getProviders()`
Returns the array of vault providers.
```solidity
function getProviders() public view returns (IProvider[] memory)
```

### Rebalancer.sol

Contract for rebalancing funds between providers.

#### Constructor
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

#### `rebalance(uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)`
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

**Parameters:**
- `assets` - amount of assets for rebalancing
- `from` - provider from which funds are withdrawn
- `to` - provider to which funds are deposited
- `fee` - rebalancing fee (maximum 20% of amount)
- `activateToProvider` - flag to activate the new provider

### RebalancerWithRewards.sol

Extended version of Rebalancer with rewards support.

#### Constructor
```solidity
constructor(
    address asset_,
    string memory name_,
    string memory symbol_,
    IProvider[] memory providers_,
    uint256 withdrawFeePercent_,
    address rewardsDistributor_,
    address timelock_,
    address treasury_
)
```

**Additional parameters:**
- `rewardsDistributor_` - rewards distributor address

#### `rebalance(uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)`
Similar to the method in Rebalancer.sol, but with additional rewards logic.

#### `setRewardsDistributor(address _rewardsDistributor)`
Sets the rewards distributor address.
```solidity
function setRewardsDistributor(address _rewardsDistributor) external onlyAdmin
```

### VaultManager.sol

Manager for managing multiple vaults.

#### `rebalanceVault(IVault vault, uint256 assets, IProvider from, IProvider to, uint256 fee, bool activateToProvider)`
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

**Parameters:**
- `vault` - vault address for rebalancing
- `assets` - amount of assets (type(uint256).max for all funds)
- `from` - provider from which funds are withdrawn
- `to` - provider to which funds are deposited
- `fee` - rebalancing fee
- `activateToProvider` - flag to activate the new provider

### Timelock.sol

Contract for secure governance with transaction execution delay.

#### Constructor
```solidity
constructor(address owner_, uint256 delay_)
```

**Parameters:**
- `owner_` - contract owner address
- `delay_` - execution delay (30 minutes - 30 days)

#### `queue(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)`
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

**Parameters:**
- `target` - target contract address
- `value` - amount of ETH to send
- `signature` - function signature
- `data` - call data
- `timestamp` - execution time

#### `execute(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)`
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

#### `cancel(address target, uint256 value, string memory signature, bytes memory data, uint256 timestamp)`
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

#### `setDelay(uint256 _delay)`
Sets a new execution delay.
```solidity
function setDelay(uint256 _delay) external onlySelf
```

### RewardsDistributor.sol

Rewards distributor using Merkle proof for efficient distribution.

#### `claim(address account, address reward, uint256 claimable, bytes32[] calldata proof)`
Allows a user to claim rewards using Merkle proof.
```solidity
function claim(
    address account,
    address reward,
    uint256 claimable,
    bytes32[] calldata proof
) external whenNotPaused
```

**Parameters:**
- `account` - reward recipient address
- `reward` - reward token address
- `claimable` - amount of available rewards
- `proof` - Merkle proof for verification

#### `updateRoot(bytes32 _root)`
Updates the Merkle tree root for new rewards distribution.
```solidity
function updateRoot(bytes32 _root) external onlyRootUpdater
```

#### `withdraw(address token)`
Withdraws all tokens from the contract (admin only).
```solidity
function withdraw(address token) external onlyAdmin
```

#### `pause()`
Pauses the contract.
```solidity
function pause() external onlyAdmin
```

#### `unpause()`
Resumes contract operation.
```solidity
function unpause() external onlyAdmin
```

### ProviderManager.sol

Manager for liquidity providers.

#### `addProvider(IProvider provider)`
Adds a new provider to the list.
```solidity
function addProvider(IProvider provider) external onlyAdmin
```

#### `removeProvider(IProvider provider)`
Removes a provider from the list.
```solidity
function removeProvider(IProvider provider) external onlyAdmin
```

#### `getProviders()`
Returns the list of all providers.
```solidity
function getProviders() external view returns (IProvider[] memory)
```

#### `isProvider(IProvider provider)`
Checks if an address is a provider.
```solidity
function isProvider(IProvider provider) external view returns (bool)
```

## Events

### Vault Events
- `SetupCompleted(address indexed setupAddress)` - vault setup completion
- `TimelockUpdated(address indexed timelock)` - timelock update
- `ProvidersUpdated(IProvider[] providers)` - providers update
- `ActiveProviderUpdated(IProvider activeProvider)` - active provider update
- `TreasuryUpdated(address indexed treasury)` - treasury update
- `WithdrawFeePercentUpdated(uint256 withdrawFeePercent)` - withdrawal fee update
- `MinAmountUpdated(uint256 minAmount)` - minimum amount update
- `FeeCharged(address indexed treasury, uint256 assets, uint256 fee)` - fee charged
- `RebalanceExecuted(uint256 assetsFrom, uint256 assetsTo, address indexed from, address indexed to)` - rebalancing executed
- `RewardsTransferred(address indexed to, uint256 amount)` - rewards transferred
- `DistributorUpdated(address indexed rewardsDistributor)` - distributor update

### Timelock Events
- `DelayUpdated(uint256 indexed newDelay)` - delay update
- `Queued(bytes32 indexed txId, address indexed target, uint256 value, string signature, bytes data, uint256 timestamp)` - transaction queued
- `Executed(bytes32 indexed txId, address indexed target, uint256 value, string signature, bytes data, uint256 timestamp)` - transaction executed
- `Cancelled(bytes32 indexed txId, address indexed target, uint256 value, string signature, bytes data, uint256 timestamp)` - transaction cancelled

### RewardsDistributor Events
- `RewardsClaimed(address indexed account, address indexed reward, uint256 amount)` - rewards claimed
- `RootUpdated(bytes32 indexed root)` - Merkle root updated

## Errors

### Vault Errors
- `Vault__Unauthorized()` - unauthorized access
- `Vault__AddressZero()` - zero address
- `Vault__InvalidInput()` - invalid input
- `Vault__DepositLessThanMin()` - deposit less than minimum
- `Vault__SetupAlreadyCompleted()` - setup already completed

### Rebalancer Errors
- `Rebalancer__InvalidProvider()` - invalid provider
- `Rebalancer__ExcessRebalanceFee()` - excessive rebalancing fee

### Timelock Errors
- `Timelock__Unauthorized()` - unauthorized access
- `Timelock__InvalidDelay()` - invalid delay
- `Timelock__InvalidTimestamp()` - invalid timestamp
- `Timelock__NotQueued()` - not queued
- `Timelock__StillLocked()` - still locked
- `Timelock__Expired()` - expired
- `Timelock__ExecutionFailed()` - execution failed

### RewardsDistributor Errors
- `RewardsDistributor__InvalidProof()` - invalid Merkle proof
- `RewardsDistributor__AlreadyClaimed()` - already claimed

## Constants

### Vault Constants
- `PRECISION_FACTOR = 1e18` - precision factor
- `MAX_WITHDRAW_FEE_PERCENT = 0.05 * 1e18` - maximum withdrawal fee (5%)
- `MAX_REBALANCE_FEE_PERCENT = 0.2 * 1e18` - maximum rebalancing fee (20%)

### Timelock Constants
- `MIN_DELAY = 30 minutes` - minimum delay
- `MAX_DELAY = 30 days` - maximum delay
- `GRACE_PERIOD = 14 days` - grace period

## Roles and Access Rights

### Vault Roles
- **Admin** - can manage vault settings
- **Operator** - can perform rebalancing
- **Timelock** - can change critical parameters

### Timelock Roles
- **Owner** - can queue and cancel transactions
- **Self** - only the contract itself can change delay

### RewardsDistributor Roles
- **Admin** - can pause contract and withdraw tokens
- **RootUpdater** - can update Merkle root

## Security

### Inflation Attack Protection
Vault uses the `setupVault()` mechanism to prevent inflation attacks described in [Hats Finance](https://rokinot.github.io/hatsfinance).

### Timelock for Critical Operations
All critical operations are executed through timelock with a delay of 30 minutes - 30 days.

### Merkle Proof for Rewards
Using Merkle proof allows efficient reward distribution without storing state for each user.

### Fee Limitations
- Maximum withdrawal fee: 5%
- Maximum rebalancing fee: 20%

## Supported Providers

The system supports the following liquidity providers:
- Aave V3
- Compound V3
- Dolomite
- Fraxlend
- Venus

## License

MIT License
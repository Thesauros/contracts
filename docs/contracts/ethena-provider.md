# Ethena Provider (Arbitrum Network)

## Overview

EthenaProvider is a provider for integrating with Ethena Protocol on the Arbitrum network, which provides 9% annual yield through delta-neutral strategies on futures markets. This provider is specifically designed for Arbitrum deployment and will integrate with Ethena Protocol when it becomes available on Arbitrum via the Converge blockchain.

## Architecture

### Core Components

1. **EthenaProvider** - main provider contract
2. **IEthenaStaking** - interface for interacting with Ethena staking contract
3. **IUSDe** - interface for USDe token

### How It Works

1. **Deposit**: Users deposit USDT/USDC, which are converted to USDe tokens
2. **Staking**: USDe tokens are staked in Ethena Protocol to earn yield
3. **Withdrawal**: When withdrawing, USDe tokens are unstaked and converted back to the base asset

## Contracts

### EthenaProvider

```solidity
contract EthenaProvider is IProvider {
    // Constants
    uint256 public constant TARGET_APY = 9e25; // 9% in ray (1e27)
    
    // State
    IEthenaStaking public immutable ethenaStaking;
    IUSDe public immutable usdeToken;
    IERC20 public immutable collateralToken;
}
```

#### Core Functions

- `deposit(uint256 amount, IVault vault)` - deposit funds to Ethena
- `withdraw(uint256 amount, IVault vault)` - withdraw funds from Ethena
- `getDepositBalance(address user, IVault vault)` - get deposit balance
- `getDepositRate(IVault vault)` - get current yield rate (9%)
- `getSource(...)` - get source address for approvals
- `getIdentifier()` - returns "Ethena_Provider"

#### Additional Functions

- `claimRewards()` - claim accumulated rewards
- `getPendingRewards(address user)` - get pending rewards
- `getCurrentAPY()` - get current APY from Ethena
- `getTotalStaked()` - get total staked amount

### IEthenaStaking

Interface for interacting with Ethena staking contract:

```solidity
interface IEthenaStaking {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getStakedBalance(address user) external view returns (uint256);
    function getCurrentAPY() external view returns (uint256);
    function getTotalStaked() external view returns (uint256);
    function claimRewards() external;
    function getPendingRewards(address user) external view returns (uint256);
}
```

### IUSDe

Interface for USDe token:

```solidity
interface IUSDe is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function getExchangeRate() external view returns (uint256);
    function isAuthorized(address account) external view returns (bool);
}
```

## Configuration

### Contract Addresses

In `utils/constants.ts`, addresses for Ethena Protocol on Arbitrum are defined:

```typescript
// Ethena Protocol addresses for Arbitrum network
// Note: Ethena Protocol is planning to deploy on Arbitrum via Converge blockchain
// These addresses will be updated when Ethena Protocol is deployed on Arbitrum
export const ethenaAddresses = {
  USDe: '0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34', // USDe token address on Arbitrum
  staking: '0x52aa899454998be5b000ad077a46bbe360f4e497', //
  // Additional Ethena contracts that may be needed:
  // mint: '0x0000000000000000000000000000000000000000', // Ethena minting contract
  // redeem: '0x0000000000000000000000000000000000000000', // Ethena redemption contract
};

export const ethenaPairs = [
  {
    asset: tokenAddresses.USDT, // Arbitrum USDT: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
    usdeToken: ethenaAddresses.USDe,
    stakingContract: ethenaAddresses.staking,
  },
  {
    asset: tokenAddresses.USDC, // Arbitrum USDC: 0xaf88d065e77c8cc2239327c5edb3a432268e5831
    usdeToken: ethenaAddresses.USDe,
    stakingContract: ethenaAddresses.staking,
  },
];
```

**Important**: 
- The addresses are currently set to zero addresses as Ethena Protocol is not yet deployed on Arbitrum
- Ethena Protocol is planning to deploy on Arbitrum via the Converge blockchain
- These addresses must be updated when Ethena Protocol becomes available on Arbitrum
- The deployment script will skip deployment if addresses are not set

## Deployment

### Deployment Script

```bash
npx hardhat deploy --tags ethena-provider --network arbitrum
```

**Note**: The deployment script will check if Ethena Protocol addresses are set. If they are zero addresses, deployment will be skipped with a warning message.

### Dependencies

EthenaProvider has no dependencies on other providers and can be deployed independently. However, it requires Ethena Protocol to be deployed on Arbitrum first.

### Network-Specific Considerations

- **Arbitrum Network**: Optimized for lower gas costs and faster transactions
- **USDT/USDC**: Uses native Arbitrum versions of these tokens
- **Converge Integration**: Will integrate with Ethena Protocol when deployed via Converge blockchain

## Testing

### Running Tests

```bash
forge test --match-contract EthenaProviderTest
```

### Test Coverage

Tests cover:
- Constructor and parameter validation
- Core provider functions
- Error handling
- Integration with mock contracts

## Security

### Recommendations

1. **Audit**: Conduct a full security audit before mainnet deployment
2. **Addresses**: Ensure correctness of Ethena Protocol contract addresses
3. **Updates**: Monitor Ethena Protocol updates and adapt integration accordingly
4. **Monitoring**: Set up monitoring for APY and overall provider status

### Risks

1. **Protocol risks**: Changes in Ethena Protocol may affect yield
2. **Liquidity**: Potential liquidity issues with large volumes
3. **Smart contract risks**: Vulnerabilities in Ethena Protocol contracts

## Monitoring

### Key Metrics

- Current APY from Ethena Protocol
- Total staked amount
- Number of active users
- Accumulated rewards

### Alerts

- APY deviation from target value (9%)
- Critical changes in Ethena Protocol
- Liquidity issues

## Integration

### Usage in Vault

EthenaProvider can be used in any Vault that supports USDT or USDC as the base asset.

### Configuration Example

```typescript
const providers = [ethenaProvider.address];
const vault = await deploy('Rebalancer', {
  args: [
    usdtAddress,
    'Thesauros USDT Vault',
    'tUSDT',
    providers,
    WITHDRAW_FEE_PERCENT,
    timelock.address,
    TREASURY_ADDRESS,
  ],
});
```

## Updates

### Versioning

When updating Ethena Protocol or changing APIs, it's necessary to:
1. Update interfaces
2. Adapt provider logic
3. Conduct testing
4. Update documentation

### Migration

To migrate to a new version:
1. Deploy new provider
2. Update Vault configuration
3. Execute fund migration
4. Disable old provider

## Arbitrum-Specific Setup

### Updating Ethena Protocol Addresses

When Ethena Protocol becomes available on Arbitrum, follow these steps:

1. **Get Official Addresses**: Obtain the official Ethena Protocol contract addresses for Arbitrum
2. **Update Configuration**: Update `utils/constants.ts` with the real addresses:

```typescript
export const ethenaAddresses = {
  USDe: '0x[ACTUAL_USDE_ADDRESS]', // Replace with actual USDe token address
  staking: '0x[ACTUAL_STAKING_ADDRESS]', // Replace with actual staking contract
  // Add other contracts as needed
};
```

3. **Deploy Provider**: Run the deployment script to deploy the provider with real addresses
4. **Test Integration**: Verify that the provider works correctly with Ethena Protocol

### Current Status

- ✅ Provider contract implemented and tested
- ✅ Arbitrum network configuration ready
- ⏳ Waiting for Ethena Protocol deployment on Arbitrum
- ⏳ Addresses need to be updated when available

### Future Integration

Once Ethena Protocol is deployed on Arbitrum:
1. The provider will automatically integrate with the real Ethena contracts
2. Users will be able to earn 9% APY through Ethena's delta-neutral strategies
3. The provider will support both USDT and USDC on Arbitrum

# Thesauros Documentation

This file contains instructions for using and building documentation for the Thesauros project.

## 📚 What's Included

The documentation includes:

- **Complete description of all methods** of contracts with usage examples
- **System architecture** with diagrams and schemas
- **Security guides** and role-based access model
- **Installation and development instructions**
- **Integration examples** and usage
- **Liquidity provider documentation**

## 🚀 Quick Start

### Viewing Documentation

1. **Online version** (if published):
   - Open the documentation website
   - Use navigation to find the information you need

2. **Local version**:
   ```bash
   # Build documentation
   ./scripts/build-docs.sh
   
   # Open in browser
   open docs/_book/index.html
   ```

### Building Documentation

```bash
# Install dependencies
npm install -g gitbook-cli

# Build
./scripts/build-docs.sh

# Or manually
cd docs
gitbook install
gitbook build
```

## 📖 Documentation Structure

```
docs/
├── README.md                    # Main page
├── SUMMARY.md                   # Table of contents
├── book.json                    # GitBook configuration
├── architecture.md              # System architecture
├── contracts/                   # Contract documentation
│   ├── vault.md                # Vault contract
│   ├── rebalancer.md           # Rebalancer contract
│   ├── timelock.md             # Timelock contract
│   ├── rewards-distributor.md  # RewardsDistributor
│   └── vault-manager.md        # VaultManager
├── security/                    # Security
│   └── roles.md                # Roles and access rights
├── development/                 # Development
│   └── installation.md         # Installation and setup
└── README_GITBOOK.md           # GitBook instructions
```

## 🔧 Main Contracts

### Vault
- **File**: `contracts/base/Vault.sol`
- **Description**: Base vault contract with ERC4626 support
- **Documentation**: [docs/contracts/vault.md](docs/contracts/vault.md)

### Rebalancer
- **File**: `contracts/Rebalancer.sol`
- **Description**: Contract for rebalancing between providers
- **Documentation**: [docs/contracts/rebalancer.md](docs/contracts/rebalancer.md)

### Timelock
- **File**: `contracts/Timelock.sol`
- **Description**: Contract for secure governance with delay
- **Documentation**: [docs/contracts/timelock.md](docs/contracts/timelock.md)

### RewardsDistributor
- **File**: `contracts/RewardsDistributor.sol`
- **Description**: Rewards distributor with Merkle proof
- **Documentation**: [docs/contracts/rewards-distributor.md](docs/contracts/rewards-distributor.md)

### VaultManager
- **File**: `contracts/VaultManager.sol`
- **Description**: Manager for managing multiple vaults
- **Documentation**: [docs/contracts/vault-manager.md](docs/contracts/vault-manager.md)

## 🛡️ Security

### Roles and Access Rights
- **Admin**: Full control over settings
- **Operator**: Execute rebalancing
- **Executor**: Management through VaultManager
- **RootUpdater**: Update Merkle root in RewardsDistributor
- **Timelock**: Critical operations with delay

Detailed information: [docs/security/roles.md](docs/security/roles.md)

### Key Security Mechanisms
- **Timelock** for critical operations
- **Role-based access model** with minimal privileges
- **Fee limitations** (maximum 5% for withdrawals, 20% for rebalancing)
- **Inflation attack protection** through `setupVault()`
- **Merkle proof** for efficient reward distribution

## 🚀 Development

### Installation and Setup
```bash
# Clone repository
git clone https://github.com/your-org/rebalance-finance.git
cd rebalance-finance

# Install dependencies
npm install

# Setup environment variables
cp .env.example .env
# Fill in the .env file

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test
```

Detailed information: [docs/development/installation.md](docs/development/installation.md)

### Testing
```bash
# Run all tests
npx hardhat test

# Run fork tests
npx hardhat test test/forking/

# Run with coverage
npx hardhat coverage
```

### Deployment
```bash
# Deploy to local network
npx hardhat run deploy/deploy-timelock.ts --network localhost
npx hardhat run deploy/deploy-providers.ts --network localhost
npx hardhat run deploy/deploy-usdc-vault.ts --network localhost

# Deploy to test network
npx hardhat run deploy/deploy-timelock.ts --network goerli
```

## 📊 Supported Providers

- **Aave V3**: Deposits and loans
- **Compound V3**: Deposits
- **Dolomite**: Trading and lending
- **Fraxlend**: Lending
- **Venus**: Deposits

## 🔄 Usage Examples

### Rebalancing Funds
```solidity
// Rebalance 1000 USDC from Aave to Compound
rebalancer.rebalance(
    1000e6,           // 1000 USDC
    aaveProvider,     // from Aave
    compoundProvider, // to Compound
    10e6,             // fee 10 USDC
    true              // activate Compound
);
```

### Management through VaultManager
```solidity
// Rebalance all funds in vault
vaultManager.rebalanceVault(
    vault,            // vault address
    type(uint256).max, // all funds
    fromProvider,     // from provider
    toProvider,       // to provider
    0,                // no fee
    true              // activate new provider
);
```

### Claiming Rewards
```solidity
// Claim rewards through Merkle proof
rewardsDistributor.claim(
    userAddress,      // user address
    rewardToken,      // reward token address
    100e6,           // reward amount
    merkleProof      // Merkle proof
);
```

## 📈 Monitoring and Analytics

### Events to Track
- `RebalanceExecuted`: Rebalancing execution
- `FeeCharged`: Fee collection
- `RewardsClaimed`: Reward claiming
- `ActiveProviderUpdated`: Active provider change

### Metrics to Monitor
- Total Value Locked (TVL)
- Provider yields
- Rebalancing frequency
- Fees and rewards
- Gas costs

## 🤝 Integration

### ERC4626 Compatibility
The system is fully compatible with the ERC4626 standard, ensuring integration with existing DeFi protocols.

### Integration API
```solidity
// Get vault information
uint256 totalAssets = vault.totalAssets();
uint256 userShares = vault.balanceOf(user);
uint256 userAssets = vault.convertToAssets(userShares);

// Get providers
IProvider[] memory providers = vault.getProviders();
IProvider activeProvider = vault.activeProvider();
```

## 📞 Support

### Getting Help
- **GitHub Issues**: Create an issue for bugs or questions
- **Documentation**: Study the relevant documentation sections
- **Tests**: Check tests for usage examples

### Useful Links
- [System Architecture](docs/architecture.md)
- [Security Guide](docs/security/roles.md)
- [Installation Instructions](docs/development/installation.md)
- [Usage Examples](docs/contracts/)

## 📝 Updating Documentation

### Adding New Methods
1. Update the corresponding documentation file in `docs/contracts/`
2. Add usage examples
3. Update `docs/SUMMARY.md` if necessary
4. Rebuild documentation

### Updating Architecture
1. Update `docs/architecture.md`
2. Add new diagrams if necessary
3. Update related documentation sections

## 🎯 Next Steps

1. **Study Architecture**: Start with [docs/architecture.md](docs/architecture.md)
2. **Run Tests**: Ensure everything works correctly
3. **Study Contracts**: Review documentation for each contract
4. **Start Development**: Use [docs/development/installation.md](docs/development/installation.md)
5. **Integrate**: Use examples from documentation

---

**Thesauros Team**  
*Created with ❤️ for the DeFi community* 
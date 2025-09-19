# Installation and Setup

Guide for installing and setting up the Thesauros project for development.

## Requirements

### System Requirements

- **Node.js** version 16 or higher
- **npm** or **yarn** for dependency management
- **Git** for repository management
- **Solidity** compiler version 0.8.23

### Recommended Tools

- **Hardhat** for development and testing
- **Foundry** for additional testing
- **MetaMask** or other Web3 wallet
- **VS Code** with Solidity extensions

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/your-org/rebalance-finance.git
cd rebalance-finance
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Install Foundry (Optional)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 4. Verify Installation

```bash
# Check Node.js
node --version

# Check npm
npm --version

# Check Hardhat
npx hardhat --version

# Check Foundry (if installed)
forge --version
```

## Configuration

### 1. Environment Variables Setup

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Fill in the required variables:

```env
# Networks
MAINNET_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
POLYGON_RPC_URL=https://polygon-rpc.com
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc

# Private keys (for testing only)
PRIVATE_KEY=your_private_key_here

# API keys
ETHERSCAN_API_KEY=your_etherscan_api_key
ALCHEMY_API_KEY=your_alchemy_api_key

# Contract addresses
TIMELOCK_ADDRESS=0x...
TREASURY_ADDRESS=0x...
REWARDS_DISTRIBUTOR_ADDRESS=0x...
```

### 2. Hardhat Configuration

The `hardhat.config.ts` file is already configured for main networks:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.23",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNET_RPC_URL || "",
      },
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
```

### 3. Foundry Configuration

If using Foundry, configure `foundry.toml`:

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc_version = "0.8.23"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

## Development Setup

### 1. Compile Contracts

```bash
# Using Hardhat
npx hardhat compile

# Using Foundry
forge build
```

### 2. Run Tests

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/mocking/Rebalancer.core.t.sol

# Run fork tests
npx hardhat test test/forking/

# Run with coverage
npx hardhat coverage

# Using Foundry
forge test
forge test --fork-url $MAINNET_RPC_URL
```

### 3. Local Development Network

```bash
# Start local network
npx hardhat node

# Deploy to local network
npx hardhat run deploy/deploy-timelock.ts --network localhost
npx hardhat run deploy/deploy-providers.ts --network localhost
npx hardhat run deploy/deploy-usdc-vault.ts --network localhost
```

## Deployment

### 1. Deploy Core Contracts

```bash
# Deploy Timelock
npx hardhat run deploy/deploy-timelock.ts --network mainnet

# Deploy Provider Manager
npx hardhat run deploy/deploy-providers.ts --network mainnet

# Deploy Vault Manager
npx hardhat run deploy/deploy-vault-manager.ts --network mainnet
```

### 2. Deploy Vaults

```bash
# Deploy USDC Vault
npx hardhat run deploy/deploy-usdc-vault.ts --network mainnet


# Deploy WETH Vault
npx hardhat run deploy/deploy-weth-vault.ts --network mainnet
```

### 3. Deploy Rewards System

```bash
# Deploy Rewards Distributor
npx hardhat run deploy/deploy-rewards-distributor.ts --network mainnet
```

## Testing

### 1. Unit Tests

```bash
# Run mocking tests
npx hardhat test test/mocking/

# Run specific test
npx hardhat test test/mocking/Rebalancer.core.t.sol
```

### 2. Fork Tests

```bash
# Run fork tests
npx hardhat test test/forking/

# Run specific fork test
npx hardhat test test/forking/AaveV3Provider.t.sol
```

### 3. Integration Tests

```bash
# Run integration tests
npx hardhat test test/integration/

# Run with specific network
npx hardhat test --network mainnet
```

## Development Workflow

### 1. Code Quality

```bash
# Lint Solidity code
npx hardhat lint

# Format code
npx hardhat format

# Check for security issues
npx hardhat security-check
```

### 2. Gas Optimization

```bash
# Gas report
npx hardhat test --gas-report

# Gas optimization analysis
npx hardhat gas-report
```

### 3. Documentation

```bash
# Generate documentation
npx hardhat docgen

# Build documentation
cd docs && gitbook build
```

## Troubleshooting

### Common Issues

#### 1. Compilation Errors

```bash
# Clear cache and recompile
npx hardhat clean
npx hardhat compile

# Check Solidity version
npx hardhat --version
```

#### 2. Network Connection Issues

```bash
# Check RPC URL
echo $MAINNET_RPC_URL

# Test connection
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $MAINNET_RPC_URL
```

#### 3. Test Failures

```bash
# Run tests with verbose output
npx hardhat test --verbose

# Run specific test with debug
npx hardhat test test/mocking/Rebalancer.core.t.sol --verbose
```

### Environment Issues

#### 1. Node.js Version

```bash
# Check Node.js version
node --version

# Use nvm to switch versions
nvm use 16
```

#### 2. Dependency Issues

```bash
# Clear npm cache
npm cache clean --force

# Remove node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### 3. Foundry Issues

```bash
# Update Foundry
foundryup

# Clear Foundry cache
forge clean
```

## Advanced Configuration

### 1. Custom Networks

Add custom networks to `hardhat.config.ts`:

```typescript
networks: {
  custom: {
    url: "https://your-rpc-url.com",
    accounts: [process.env.PRIVATE_KEY || ""],
    chainId: 1337,
  },
}
```

### 2. Plugin Configuration

Configure additional plugins:

```typescript
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";
import "hardhat-gas-reporter";
import "solidity-coverage";

const config: HardhatUserConfig = {
  // ... existing config
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  coverage: {
    exclude: ["test/", "deploy/"],
  },
};
```

### 3. Scripts Configuration

Create custom scripts in `scripts/`:

```typescript
// scripts/deploy-all.ts
import { ethers } from "hardhat";

async function main() {
  // Deploy all contracts
  const timelock = await deployTimelock();
  const providers = await deployProviders();
  const vaults = await deployVaults();
  
  console.log("All contracts deployed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## Security Considerations

### 1. Private Key Management

- Never commit private keys to version control
- Use environment variables for sensitive data
- Consider using hardware wallets for production

### 2. Network Security

- Use secure RPC endpoints
- Verify contract addresses before deployment
- Test on testnets before mainnet

### 3. Code Security

- Run security audits before deployment
- Use static analysis tools
- Follow security best practices

## Performance Optimization

### 1. Compilation Optimization

```typescript
solidity: {
  version: "0.8.23",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
  },
}
```

### 2. Test Optimization

```bash
# Run tests in parallel
npx hardhat test --parallel

# Use specific test patterns
npx hardhat test --grep "rebalance"
```

### 3. Deployment Optimization

```bash
# Use deterministic deployment
npx hardhat run deploy/deploy-deterministic.ts --network mainnet

# Batch deployments
npx hardhat run deploy/deploy-batch.ts --network mainnet
```

## Monitoring and Maintenance

### 1. Contract Monitoring

```bash
# Monitor contract events
npx hardhat monitor --contract 0x... --network mainnet

# Check contract state
npx hardhat check-state --contract 0x... --network mainnet
```

### 2. Performance Monitoring

```bash
# Gas usage monitoring
npx hardhat gas-report --network mainnet

# Transaction monitoring
npx hardhat monitor-tx --tx 0x... --network mainnet
```

### 3. Maintenance Scripts

```bash
# Update contract parameters
npx hardhat run scripts/maintenance/update-params.ts --network mainnet

# Emergency procedures
npx hardhat run scripts/maintenance/emergency-pause.ts --network mainnet
```

## Best Practices

### 1. Development Workflow

1. **Feature Branches**: Work on feature branches
2. **Code Review**: Require code reviews before merging
3. **Testing**: Write comprehensive tests
4. **Documentation**: Keep documentation updated

### 2. Deployment Process

1. **Testnet Deployment**: Deploy to testnet first
2. **Testing**: Thoroughly test on testnet
3. **Audit**: Conduct security audit
4. **Mainnet Deployment**: Deploy to mainnet with timelock

### 3. Monitoring

1. **Event Monitoring**: Monitor contract events
2. **Performance Monitoring**: Track gas usage and performance
3. **Security Monitoring**: Monitor for suspicious activity
4. **User Support**: Provide user support and documentation

## Support and Resources

### 1. Documentation

- [Hardhat Documentation](https://hardhat.org/docs)
- [Foundry Documentation](https://book.getfoundry.sh)
- [Solidity Documentation](https://docs.soliditylang.org)

### 2. Community

- [Discord Server](https://discord.gg/rebalance-finance)
- [GitHub Issues](https://github.com/your-org/rebalance-finance/issues)
- [Telegram Group](https://t.me/rebalance-finance)

### 3. Tools

- [Etherscan](https://etherscan.io) - Blockchain explorer
- [Tenderly](https://tenderly.co) - Debugging and monitoring
- [OpenZeppelin](https://openzeppelin.com) - Security tools 
# Thesauros: Documentation

Welcome to the Thesauros smart contract documentation - a system for automatic interest rebalancing between various liquidity providers.

## What is Thesauros?

Thesauros is a decentralized system that automatically redistributes funds between various DeFi protocols to maximize yield. The system supports the ERC4626 standard and provides secure asset management through timelock mechanisms and role-based access control.

## Key Features

- **Automatic Rebalancing** - redistribution of funds between providers to maximize yield
- **ERC4626 Compatibility** - full support for vault token standard
- **Security** - timelock for critical operations and inflation attack protection
- **Flexibility** - support for multiple liquidity providers
- **Rewards** - reward distribution system through Merkle proof
- **Management** - centralized management of multiple vaults

## Supported Providers

- Aave V3
- Compound V3
- Dolomite
- Fraxlend
- Venus

## Quick Start

1. [Installation](development/installation.md)
2. [System Architecture](architecture.md)
3. [Contract Deployment](development/deployment.md)

## Contract Documentation

- [Vault](contracts/vault.md) - base vault contract with ERC4626 support
- [Rebalancer](contracts/rebalancer.md) - contract for rebalancing between providers
- [RebalancerWithRewards](contracts/rebalancer-with-rewards.md) - extended version with rewards support
- [VaultManager](contracts/vault-manager.md) - manager for managing multiple vaults
- [Timelock](contracts/timelock.md) - contract for secure governance with delay
- [RewardsDistributor](contracts/rewards-distributor.md) - rewards distributor with Merkle proof

## Security

- [Roles and Access Rights](security/roles.md)
- [Contract Security](security/contract-security.md)
- [Attacks and Protection](security/attacks-protection.md)

## Development

- [Testing](development/testing.md)
- [Audit](development/audit.md)

## License

MIT License 
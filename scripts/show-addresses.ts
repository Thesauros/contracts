import { ethers } from 'hardhat';
import { deployments } from 'hardhat';

async function main() {
  console.log('Starting Thesauros Deployed Contracts on Arbitrum One');
  console.log('==============================================\n');

  // Base Contracts
  console.log('  Base Contracts:');
  console.log('------------------');
  
  try {
    const timelock = await deployments.get('Timelock');
    console.log(`Timelock: ${timelock.address}`);
  } catch (e) {
    console.log('Timelock: Not deployed');
  }

  try {
    const vaultManager = await deployments.get('VaultManager');
    console.log(`VaultManager: ${vaultManager.address}`);
  } catch (e) {
    console.log('VaultManager: Not deployed');
  }

  try {
    const providerManager = await deployments.get('ProviderManager');
    console.log(`ProviderManager: ${providerManager.address}`);
  } catch (e) {
    console.log('ProviderManager: Not deployed');
  }

  try {
    const aaveV3Provider = await deployments.get('AaveV3Provider');
    console.log(`AaveV3Provider: ${aaveV3Provider.address}`);
  } catch (e) {
    console.log('AaveV3Provider: Not deployed');
  }

  try {
    const compoundV3Provider = await deployments.get('CompoundV3Provider');
    console.log(`CompoundV3Provider: ${compoundV3Provider.address}`);
  } catch (e) {
    console.log('CompoundV3Provider: Not deployed');
  }

  console.log('\nVaults Vaults:');
  console.log('----------');
  
  // Known vault addresses from our deployments
  const vaultAddresses = {
    'WETH Vault': '0x78c11f63E6840820be18fDA461Ab16f23da5884f',
    'USDC Vault': '0xdf5AFad7f88888bEE944d14982c2d9eBA65653e6',
    'USDT Vault': '0xe1D34AB80090da3498Fc5D0696a2Cf82971E5eC6',
  };

  for (const [name, address] of Object.entries(vaultAddresses)) {
    console.log(`${name}: ${address}`);
  }

  console.log('\n  Token Addresses:');
  console.log('------------------');
  
  const tokenAddresses = {
    'WETH': '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    'USDC': '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    'USDT': '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
    'USDC.e': '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8'
  };

  for (const [name, address] of Object.entries(tokenAddresses)) {
    console.log(`${name}: ${address}`);
  }

  console.log('\n   Treasury:');
  console.log('------------');
  console.log('Treasury: 0xc8a682F0991323777253ffa5fa6F19035685E723');

  console.log('\nFiles Deployment files location:');
  console.log('deployments/arbitrumOne/');
  console.log('deployments/arbitrumOne/deployed-vaults.json');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

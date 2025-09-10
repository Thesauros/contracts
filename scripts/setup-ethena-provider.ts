import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { deployedVaults } from '../utils/config';
import { ARBITRUM_CHAIN_ID } from '../utils/constants';

async function setupEthenaProvider(hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  console.log('Setting up Ethena Provider for existing vaults...');
  console.log('Deployer:', deployer);

  // Get deployed contracts
  const providerManager = await ethers.getContractAt(
    'ProviderManager',
    (await deployments.get('ProviderManager')).address
  );

  const vaultManager = await ethers.getContractAt(
    'VaultManager',
    (await deployments.get('VaultManager')).address
  );

  // Get Ethena providers for USDT and USDC
  const ethenaProviderUSDT = await deployments.get('EthenaProvider_USDT');
  const ethenaProviderUSDC = await deployments.get('EthenaProvider_USDC');

  console.log('EthenaProvider USDT:', ethenaProviderUSDT.address);
  console.log('EthenaProvider USDC:', ethenaProviderUSDC.address);

  // Get vault addresses
  const usdtVaultAddress = deployedVaults.vaults.USDT.address;
  const usdcVaultAddress = deployedVaults.vaults.USDC.address;

  console.log('USDT Vault:', usdtVaultAddress);
  console.log('USDC Vault:', usdcVaultAddress);

  // Add Ethena providers to ProviderManager
  console.log('\nAdding Ethena providers to ProviderManager...');
  
  const addProviderTx1 = await providerManager.addProvider(
    ethenaProviderUSDT.address,
    'Ethena USDT Provider'
  );
  await addProviderTx1.wait();
  console.log('Added EthenaProvider USDT to ProviderManager');

  const addProviderTx2 = await providerManager.addProvider(
    ethenaProviderUSDC.address,
    'Ethena USDC Provider'
  );
  await addProviderTx2.wait();
  console.log('Added EthenaProvider USDC to ProviderManager');

  // Get vault contracts
  const usdtVault = await ethers.getContractAt('Vault', usdtVaultAddress);
  const usdcVault = await ethers.getContractAt('Vault', usdcVaultAddress);

  // Add Ethena providers to vaults
  console.log('\nAdding Ethena providers to vaults...');
  
  const addProviderToVaultTx1 = await usdtVault.addProvider(
    ethenaProviderUSDT.address
  );
  await addProviderToVaultTx1.wait();
  console.log('Added EthenaProvider to USDT vault');

  const addProviderToVaultTx2 = await usdcVault.addProvider(
    ethenaProviderUSDC.address
  );
  await addProviderToVaultTx2.wait();
  console.log('Added EthenaProvider to USDC vault');

  // Set provider weights (optional - for rebalancing)
  console.log('\nSetting provider weights...');
  
  const setWeightTx1 = await usdtVault.setProviderWeight(
    ethenaProviderUSDT.address,
    ethers.parseEther('0.3') // 30% weight
  );
  await setWeightTx1.wait();
  console.log('Set EthenaProvider weight to 30% for USDT vault');

  const setWeightTx2 = await usdcVault.setProviderWeight(
    ethenaProviderUSDC.address,
    ethers.parseEther('0.3') // 30% weight
  );
  await setWeightTx2.wait();
  console.log('Set EthenaProvider weight to 30% for USDC vault');

  console.log('\nEthena Provider setup completed successfully!');
  console.log('\nSummary:');
  console.log('- EthenaProvider USDT:', ethenaProviderUSDT.address);
  console.log('- EthenaProvider USDC:', ethenaProviderUSDC.address);
  console.log('- Connected to USDT Vault:', usdtVaultAddress);
  console.log('- Connected to USDC Vault:', usdcVaultAddress);
  console.log('- Provider weights set to 30% for both vaults');
}

// Execute the setup
setupEthenaProvider(hre)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

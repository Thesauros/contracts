import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import { ARBITRUM_CHAIN_ID, morphoVaults, tokenAddresses } from '../utils/constants';
import { verify } from '../utils/verify';

const deployMorphoProvider: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log, get } = deployments;
  const { deployer } = await getNamedAccounts();

  log('----------------------------------------------------');
  log('Deploying MorphoProvider...');

  // Get or deploy ProviderManager
  let providerManager;
  try {
    providerManager = await get('ProviderManager');
    log(`Using existing ProviderManager at ${providerManager.address}`);
  } catch (error) {
    log('ProviderManager not found, deploying...');
    providerManager = await deploy('ProviderManager', {
      from: deployer,
      args: [deployer],
      log: true,
    });
    log(`ProviderManager deployed at ${providerManager.address}`);
  }

  // Choose a MetaMorpho vault to use (we'll use Gauntlet Core as it's a well-known strategy)
  const selectedVault = morphoVaults.find(vault => vault.strategy === 'Gauntlet Core');
  if (!selectedVault) {
    throw new Error('Gauntlet Core MetaMorpho vault not found in constants');
  }

  log(`Using MetaMorpho vault: ${selectedVault.strategy} at ${selectedVault.vaultAddress}`);

  // Deploy MorphoProvider with the MetaMorpho vault address
  const morphoProvider = await deploy('MorphoProvider', {
    from: deployer,
    args: [selectedVault.vaultAddress],
    log: true,
  });

  log(`MorphoProvider deployed at ${morphoProvider.address}`);

  // Verify the contract on Arbitrum
  if ((await ethers.provider.getNetwork()).chainId === ARBITRUM_CHAIN_ID) {
    await verify(morphoProvider.address, [selectedVault.vaultAddress]);
  }

  log('----------------------------------------------------');
  log('Setting up MorphoProvider in ProviderManager...');

  const providerManagerInstance = await ethers.getContractAt(
    'ProviderManager',
    providerManager.address
  );

  // Register MorphoProvider in ProviderManager for USDC
  // For Morpho, we use the MetaMorpho vault address as the "yield token"
  // since the vault itself represents the yield-bearing position
  const usdcAsset = tokenAddresses.USDC;
  
  await providerManagerInstance.setYieldToken(
    'Morpho_Provider',
    usdcAsset,
    selectedVault.vaultAddress // Using MetaMorpho vault address as yield token
  );
  log(`Registered USDC (${usdcAsset}) for Morpho_Provider with vault ${selectedVault.vaultAddress}`);

  log('----------------------------------------------------');
  log('MorphoProvider deployment completed!');
  log(`MorphoProvider address: ${morphoProvider.address}`);
  log(`ProviderManager address: ${providerManager.address}`);
  log(`MetaMorpho vault: ${selectedVault.strategy} at ${selectedVault.vaultAddress}`);
  log('----------------------------------------------------');

  // Log available MetaMorpho vaults for reference
  log('Available MetaMorpho vaults on Arbitrum:');
  morphoVaults.forEach(vault => {
    log(`  ${vault.strategy}: ${vault.vaultAddress}`);
  });
  log('----------------------------------------------------');
};

export default deployMorphoProvider;
deployMorphoProvider.tags = ['morpho-provider'];
deployMorphoProvider.dependencies = []; // No dependencies - we'll get ProviderManager manually

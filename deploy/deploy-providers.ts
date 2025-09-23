import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import { BASE_CHAIN_ID, cometPairs, morphoVaults } from '../utils/constants';
import { verify } from '../utils/verify';

const deployProviders: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const waitConfirmations = chainId === BASE_CHAIN_ID ? 2 : 0;

  log('----------------------------------------------------');
  log('Deploying ProviderManager...');

  const providerManager = await deploy('ProviderManager', {
    from: deployer,
    args: [deployer],
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`ProviderManager at ${providerManager.address}`);

  const providerManagerInstance = await ethers.getContractAt(
    'ProviderManager',
    providerManager.address
  );

  log('----------------------------------------------------');
  log('Setting up yield tokens...');

  for (const { asset, cToken } of cometPairs) {
    await providerManagerInstance.setYieldToken(
      'Compound_V3_Provider',
      asset,
      cToken
    );
  }

  if (chainId === BASE_CHAIN_ID) {
    await verify(providerManager.address, [deployer]);
  }

  log('----------------------------------------------------');
  log('Deploying Morpho providers...');

  for (const { strategy, vaultAddress } of morphoVaults) {
    const provider = await deploy('MorphoProvider', {
      from: deployer,
      args: [vaultAddress],
      log: true,
      waitConfirmations: waitConfirmations,
    });

    log('----------------------------------------------------');
    log(`MorphoProvider for ${strategy} strategy at ${provider.address}`);

    if (chainId === BASE_CHAIN_ID) {
      await verify(provider.address, [vaultAddress]);
    }
  }

  log('----------------------------------------------------');
  log('Deploying AaveV3 and CompoundV3 providers...');

  const providersToDeploy = ['AaveV3Provider', 'CompoundV3Provider'];

  for (const providerName of providersToDeploy) {
    const args =
      providerName === 'CompoundV3Provider' ? [providerManager.address] : [];

    const provider = await deploy(providerName, {
      from: deployer,
      args: args,
      log: true,
      waitConfirmations: waitConfirmations,
    });

    log('----------------------------------------------------');
    log(`${providerName} at ${provider.address}`);

    if (chainId === BASE_CHAIN_ID) {
      await verify(provider.address, args);
    }
  }
};

export default deployProviders;
deployProviders.tags = ['all', 'providers'];

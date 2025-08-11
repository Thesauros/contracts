import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import { ARBITRUM_CHAIN_ID, cometPairs } from '../utils/constants';
import { verify } from '../utils/verify';

const deployProviders: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const providersToDeploy = ['AaveV3Provider', 'CompoundV3Provider'];

  log('----------------------------------------------------');
  log('Deploying ProviderManager...');

  const providerManager = await deploy('ProviderManager', {
    from: deployer,
    args: [],
    log: true,
  });

  if ((await ethers.provider.getNetwork()).chainId === ARBITRUM_CHAIN_ID) {
    await verify(providerManager.address, []);
  }

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

  log('----------------------------------------------------');
  log('Deploying all the providers...');

  for (const providerName of providersToDeploy) {
    const args =
      providerName === 'CompoundV3Provider' ? [providerManager.address] : [];

    const provider = await deploy(providerName, {
      from: deployer,
      args: args,
      log: true,
    });

    log(`${providerName} deployed at ${provider.address}`);
    log('----------------------------------------------------');

    if ((await ethers.provider.getNetwork()).chainId === ARBITRUM_CHAIN_ID) {
      await verify(provider.address, args);
    }
  }
};

export default deployProviders;
deployProviders.tags = ['all', 'providers'];

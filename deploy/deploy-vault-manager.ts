import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import { BASE_CHAIN_ID } from '../utils/constants';
import { verify } from '../utils/verify';

const deployVaultManager: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const waitConfirmations = chainId === BASE_CHAIN_ID ? 2 : 0;

  log('----------------------------------------------------');
  log('Deploying VaultManager...');

  const vaultManager = await deploy('VaultManager', {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`VaultManager at ${vaultManager.address}`);

  if (chainId === BASE_CHAIN_ID) {
    await verify(vaultManager.address, []);
  }
};

export default deployVaultManager;
deployVaultManager.tags = ['all', 'vault-manager'];

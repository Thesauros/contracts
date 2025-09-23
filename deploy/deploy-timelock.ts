import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import { BASE_CHAIN_ID } from '../utils/constants';
import { verify } from '../utils/verify';

const deployTimelock: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const waitConfirmations = chainId === BASE_CHAIN_ID ? 2 : 0;

  log('----------------------------------------------------');
  log('Deploying Timelock...');

  const thirtyMinutes = 1800; // 30 minutes - minimum required by Timelock contract

  const timelock = await deploy('Timelock', {
    from: deployer,
    args: [deployer, thirtyMinutes],
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`Timelock at ${timelock.address}`);

  if (chainId === BASE_CHAIN_ID) {
    await verify(timelock.address, [deployer, thirtyMinutes]);
  }
};

export default deployTimelock;
deployTimelock.tags = ['all', 'timelock'];

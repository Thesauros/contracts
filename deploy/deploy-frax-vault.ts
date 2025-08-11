import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import {
  ARBITRUM_CHAIN_ID,
  TREASURY_ADDRESS,
  WITHDRAW_FEE_PERCENT,
  OPERATOR_ROLE,
  tokenAddresses,
} from '../utils/constants';
import { verify } from '../utils/verify';

const deployFraxVault: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = 'Rebalance FRAX';
  const symbol = 'rFRAX';

  const fraxAddress = tokenAddresses.FRAX;

  const initialDeposit = ethers.parseEther('1'); // Be sure that you have the balance available in the deployer account

  log('----------------------------------------------------');
  log('Deploying Distributor...');

  const rewardsDistributor = await deploy('RewardsDistributor', {
    from: deployer,
    args: [],
    log: true,
  });

  log('----------------------------------------------------');
  log('Deploying FRAX Rebalancer...');

  const [vaultManager, timelock, aaveV3Provider] = await Promise.all([
    deployments.get('VaultManager'),
    deployments.get('Timelock'),
    deployments.get('AaveV3Provider'),
  ]);

  const providers = [aaveV3Provider.address];

  const args = [
    fraxAddress,
    name,
    symbol,
    providers,
    WITHDRAW_FEE_PERCENT,
    rewardsDistributor.address,
    timelock.address,
    TREASURY_ADDRESS,
  ];

  const fraxRebalancer = await deploy('RebalancerWithRewards', {
    from: deployer,
    args: args,
    log: true,
  });

  log(`FRAX Rebalancer at ${fraxRebalancer.address}`);
  log('----------------------------------------------------');

  const fraxInstance = await ethers.getContractAt('IERC20', fraxAddress);
  await fraxInstance.approve(fraxRebalancer.address, initialDeposit);

  const fraxRebalancerInstance = await ethers.getContractAt(
    'RebalancerWithRewards',
    fraxRebalancer.address
  );
  await fraxRebalancerInstance.grantRole(OPERATOR_ROLE, vaultManager.address);
  await fraxRebalancerInstance.setupVault(initialDeposit);

  if ((await ethers.provider.getNetwork()).chainId === ARBITRUM_CHAIN_ID) {
    await verify(fraxRebalancer.address, args);
    await verify(rewardsDistributor.address, []);
  }
};

export default deployFraxVault;
deployFraxVault.tags = ['all', 'frax-vault'];
// deployFraxVault.dependencies = ['vault-manager', 'providers', 'timelock'];

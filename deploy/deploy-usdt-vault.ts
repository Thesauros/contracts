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

const deployUsdtVault: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = 'Thesauros USDT Vault';
  const symbol = 'tUSDT';

  const usdtAddress = tokenAddresses.USDT;

  const initialDeposit = ethers.parseUnits('1', 6); // Be sure that you have the balance available in the deployer account

  log('----------------------------------------------------');
  log('Deploying USDT Rebalancer...');

  const [vaultManager, timelock, compoundV3Provider, aaveV3Provider] =
    await Promise.all([
      deployments.get('VaultManager'),
      deployments.get('Timelock'),
      deployments.get('CompoundV3Provider'),
      deployments.get('AaveV3Provider'),
    ]);

  const providers = [compoundV3Provider.address, aaveV3Provider.address];

  const args = [
    usdtAddress,
    name,
    symbol,
    providers,
    WITHDRAW_FEE_PERCENT,
    timelock.address,
    TREASURY_ADDRESS,
  ];

  const usdtRebalancer = await deploy('Rebalancer', {
    from: deployer,
    args: args,
    log: true,
  });

  log(`USDT Rebalancer at ${usdtRebalancer.address}`);
  log('----------------------------------------------------');

  const usdtInstance = await ethers.getContractAt('IERC20', usdtAddress);
  await usdtInstance.approve(usdtRebalancer.address, initialDeposit);

  const usdtRebalancerInstance = await ethers.getContractAt(
    'Rebalancer',
    usdtRebalancer.address
  );
  await usdtRebalancerInstance.grantRole(OPERATOR_ROLE, vaultManager.address);
  await usdtRebalancerInstance.setupVault(initialDeposit);

  if ((await ethers.provider.getNetwork()).chainId === ARBITRUM_CHAIN_ID) {
    await verify(usdtRebalancer.address, args);
  }
};

export default deployUsdtVault;
deployUsdtVault.tags = ['all', 'usdt-vault'];
// deployUsdtVault.dependencies = ['vault-manager', 'providers', 'timelock'];

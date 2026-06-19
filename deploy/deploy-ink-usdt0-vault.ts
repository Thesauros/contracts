import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import {
  INK_CHAIN_ID,
  TREASURY_ADDRESS,
  WITHDRAW_FEE_PERCENT,
  TIMELOCK_DELAY,
  OPERATOR_ROLE,
  inkTokenAddresses,
} from '../utils/constants';
import { verify } from '../utils/verify';

const deployInkUsdt0Vault: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  if (!TREASURY_ADDRESS) {
    throw new Error('TREASURY_ADDRESS is required');
  }

  const name = 'Thesauros USDT0 Vault';
  const symbol = 'tUSDT0';

  const usdt0Address = inkTokenAddresses.USDT0;
  const initialDeposit = ethers.parseUnits('1', 6);
  const providers: string[] = [];
  const waitConfirmations = 2;

  // Only the Aave V3 (Tydro) strategy is deployed on Ink, so no ProviderManager
  // is needed (it only serves CompoundV3Provider yield-token lookups).
  // AaveV3InkProvider hardcodes the Tydro PoolAddressesProvider, so it takes
  // no constructor arguments.
  log('----------------------------------------------------');
  log('Deploying Ink AaveV3InkProvider...');

  const aaveV3Provider = await deploy('AaveV3InkProvider', {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`AaveV3InkProvider at ${aaveV3Provider.address}`);

  providers.push(aaveV3Provider.address);

  log('----------------------------------------------------');
  log('Deploying Timelock...');

  const timelock = await deploy('Timelock', {
    from: deployer,
    args: [deployer, TIMELOCK_DELAY],
    log: true,
    waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`Timelock at ${timelock.address}`);

  log('----------------------------------------------------');
  log('Deploying VaultManager...');

  const vaultManager = await deploy('VaultManager', {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`VaultManager at ${vaultManager.address}`);

  log('----------------------------------------------------');
  log('Deploying Ink USDT0 Rebalancer...');

  const rebalancerArgs = [
    usdt0Address,
    name,
    symbol,
    providers,
    WITHDRAW_FEE_PERCENT,
    timelock.address,
    TREASURY_ADDRESS,
  ];

  const usdt0Rebalancer = await deploy('Rebalancer', {
    from: deployer,
    args: rebalancerArgs,
    log: true,
    waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`USDT0 Rebalancer at ${usdt0Rebalancer.address}`);

  const usdt0Instance = await ethers.getContractAt('IERC20', usdt0Address);
  await usdt0Instance
    .approve(usdt0Rebalancer.address, initialDeposit)
    .then((tx) => tx.wait());

  const usdt0RebalancerInstance = await ethers.getContractAt(
    'Rebalancer',
    usdt0Rebalancer.address
  );
  await usdt0RebalancerInstance
    .grantRole(OPERATOR_ROLE, vaultManager.address)
    .then((tx) => tx.wait());
  await usdt0RebalancerInstance
    .setupVault(initialDeposit)
    .then((tx) => tx.wait());

  if (process.env.VERIFY_CONTRACTS === 'true') {
    await verify(aaveV3Provider.address, []);
    await verify(timelock.address, [deployer, TIMELOCK_DELAY]);
    await verify(vaultManager.address, []);
    await verify(usdt0Rebalancer.address, rebalancerArgs);
  }
};

export default deployInkUsdt0Vault;
deployInkUsdt0Vault.tags = ['all', 'ink-usdt0-vault'];
deployInkUsdt0Vault.skip = async () =>
  (await ethers.provider.getNetwork()).chainId !== INK_CHAIN_ID;

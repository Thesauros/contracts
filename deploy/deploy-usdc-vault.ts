import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import {
  ARBITRUM_CHAIN_ID,
  TREASURY_ADDRESS,
  WITHDRAW_FEE_PERCENT,
  TIMELOCK_DELAY,
  OPERATOR_ROLE,
  tokenAddresses,
  cometPairs,
  morphoVaults,
} from '../utils/constants';
import { verify } from '../utils/verify';

const deployUsdcVault: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  // @ts-ignore
  const { getNamedAccounts, deployments } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const waitConfirmations = chainId === ARBITRUM_CHAIN_ID ? 2 : 0;

  const name = 'Thesauros USDC Vault';
  const symbol = 'tUSDC';

  const usdcAddress = tokenAddresses.USDC;

  const initialDeposit = ethers.parseUnits('1', 6); // Be sure that you have the balance available in the deployer account

  const providers: string[] = [];

  /*//////////////////////////////////////////////////////////////
                            DEPLOY PROVIDERS
  //////////////////////////////////////////////////////////////*/

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
    await providerManagerInstance
      .setYieldToken('Compound_V3_Provider', asset, cToken)
      .then((tx) => tx.wait());
  }

  if (chainId === ARBITRUM_CHAIN_ID) {
    await verify(providerManager.address, [deployer]);
  }

  log('----------------------------------------------------');
  log('Deploying AaveV3, CompoundV3 and Dolomite providers...');

  const providersToDeploy = [
    'CompoundV3Provider',
    'AaveV3Provider',
    'DolomiteProvider',
  ];

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

    providers.push(provider.address);

    if (chainId === ARBITRUM_CHAIN_ID) {
      await verify(provider.address, args);
    }
  }

  log('----------------------------------------------------');
  log('Deploying Morpho providers...');

  for (const { strategy, vaultAddress } of morphoVaults) {
    const deploymentName = `${strategy}MorphoProvider`;
    const provider = await deploy(deploymentName, {
      contract: 'MorphoProvider',
      from: deployer,
      args: [vaultAddress],
      log: true,
      waitConfirmations: waitConfirmations,
    });

    log('----------------------------------------------------');
    log(`MorphoProvider for ${strategy} strategy at ${provider.address}`);

    providers.push(provider.address);

    if (chainId === ARBITRUM_CHAIN_ID) {
      await verify(provider.address, [vaultAddress]);
    }
  }

  /*//////////////////////////////////////////////////////////////
                            DEPLOY TIMELOCK
  //////////////////////////////////////////////////////////////*/

  log('----------------------------------------------------');
  log('Deploying Timelock...');

  const timelock = await deploy('Timelock', {
    from: deployer,
    args: [deployer, TIMELOCK_DELAY],
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`Timelock at ${timelock.address}`);

  if (chainId === ARBITRUM_CHAIN_ID) {
    await verify(timelock.address, [deployer, TIMELOCK_DELAY]);
  }

  /*//////////////////////////////////////////////////////////////
                          DEPLOY VAULT MANAGER
  //////////////////////////////////////////////////////////////*/

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

  if (chainId === ARBITRUM_CHAIN_ID) {
    await verify(vaultManager.address, []);
  }

  /*//////////////////////////////////////////////////////////////
                         DEPLOY USDC REBALANCER
  //////////////////////////////////////////////////////////////*/

  log('----------------------------------------------------');
  log('Deploying USDC Rebalancer...');

  const args = [
    usdcAddress,
    name,
    symbol,
    providers,
    WITHDRAW_FEE_PERCENT,
    timelock.address,
    TREASURY_ADDRESS,
  ];

  // For other tokens, use the same unique-name pattern (like morpho) so hardhat-deploy auto-saves each deployment separately.
  const usdcRebalancer = await deploy('Rebalancer', {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`USDC Rebalancer at ${usdcRebalancer.address}`);

  const usdcInstance = await ethers.getContractAt('IERC20', usdcAddress);
  await usdcInstance
    .approve(usdcRebalancer.address, initialDeposit)
    .then((tx) => tx.wait());

  const usdcRebalancerInstance = await ethers.getContractAt(
    'Rebalancer',
    usdcRebalancer.address
  );
  await usdcRebalancerInstance
    .grantRole(OPERATOR_ROLE, vaultManager.address)
    .then((tx) => tx.wait());
  await usdcRebalancerInstance
    .setupVault(initialDeposit)
    .then((tx) => tx.wait());

  if (chainId === ARBITRUM_CHAIN_ID) {
    await verify(usdcRebalancer.address, args);
  }
};

export default deployUsdcVault;
deployUsdcVault.tags = ['all', 'usdc-vault'];

import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import {
  BASE_CHAIN_ID,
  TREASURY_ADDRESS,
  WITHDRAW_FEE_PERCENT,
  OPERATOR_ROLE,
  tokenAddresses,
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
  const waitConfirmations = chainId === BASE_CHAIN_ID ? 2 : 0;

  const name = 'Thesauros USDC';
  const symbol = 'tUSDC';

  const usdcAddress = tokenAddresses.USDC;

  // Get Morpho provider addresses from constants
  const sparkMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Spark')?.vaultAddress;
  const moonwellMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Moonwell')?.vaultAddress;
  const seamlessMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Seamless')?.vaultAddress;
  const steakhouseMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Steakhouse')?.vaultAddress;
  const gauntletPrimeMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Gauntlet Prime')?.vaultAddress;
  const gauntletCoreMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Gauntlet Core')?.vaultAddress;
  const apostroResolvMorphoProviderAddress = morphoVaults.find(v => v.strategy === 'Apostro Resolv')?.vaultAddress;

  const initialDeposit = ethers.parseUnits('1', 6); // Be sure that you have the balance available in the deployer account

  log('----------------------------------------------------');
  log('Deploying USDC Thesauros Vault...');

  const [vaultManager, timelock, compoundV3Provider, aaveV3Provider] =
    await Promise.all([
      deployments.get('VaultManager'),
      deployments.get('Timelock'),
      deployments.get('CompoundV3Provider'),
      deployments.get('AaveV3Provider'),
    ]);

  const providers = [
    sparkMorphoProviderAddress!,
    moonwellMorphoProviderAddress!,
    seamlessMorphoProviderAddress!,
    steakhouseMorphoProviderAddress!,
    gauntletPrimeMorphoProviderAddress!,
    gauntletCoreMorphoProviderAddress!,
    apostroResolvMorphoProviderAddress!,
    compoundV3Provider.address,
    aaveV3Provider.address,
  ];

  const args = [
    usdcAddress,
    name,
    symbol,
    providers,
    WITHDRAW_FEE_PERCENT,
    timelock.address,
    TREASURY_ADDRESS,
  ];

  const usdcRebalancer = await deploy('Rebalancer', {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`USDC Thesauros Vault at ${usdcRebalancer.address}`);

  const usdcInstance = await ethers.getContractAt('IERC20', usdcAddress);
  await usdcInstance.approve(usdcRebalancer.address, initialDeposit);

  const usdcRebalancerInstance = await ethers.getContractAt(
    'Rebalancer',
    usdcRebalancer.address
  );
  await usdcRebalancerInstance.grantRole(OPERATOR_ROLE, vaultManager.address);
  await usdcRebalancerInstance.setupVault(initialDeposit);

  if (chainId === BASE_CHAIN_ID) {
    await verify(usdcRebalancer.address, args);
  }
};

export default deployUsdcVault;
deployUsdcVault.tags = ['all', 'usdc-vault'];
// deployUsdcVault.dependencies = ['vault-manager', 'providers', 'timelock'];

import { ethers } from 'hardhat';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

import {
  BASE_CHAIN_ID,
  TREASURY_ADDRESS,
  WITHDRAW_FEE_PERCENT,
  OPERATOR_ROLE,
  tokenAddresses,
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

  const sparkMorphoProviderAddress =
    '0x048877bc6F9306831570893d471d173BA59F8E57';
  const moonwellMorphoProviderAddress =
    '0xfFcB03d87Adc55a49A91828e84a62e2be16367CC';
  const seamlessMorphoProviderAddress =
    '0xF5862e8db0c543C3887878127496cce22c42362f';
  const steakhouseMorphoProviderAddress =
    '0x407472f6cEa7b092545Db90770B852f6bD89B619';
  const gauntletPrimeMorphoProviderAddress =
    '0xCF86c768E5b8bcc823aC1D825F56f37c533d32F9';
  const gauntletCoreMorphoProviderAddress =
    '0x8a0cd3Bc1A4B41fB0cB54673E1E7F2699E934359';
  const apostroResolvMorphoProviderAddress =
    '0xD0F8808EbD267d4bdf6bA893f995b5501105f715';

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
    sparkMorphoProviderAddress,
    moonwellMorphoProviderAddress,
    seamlessMorphoProviderAddress,
    steakhouseMorphoProviderAddress,
    gauntletPrimeMorphoProviderAddress,
    gauntletCoreMorphoProviderAddress,
    apostroResolvMorphoProviderAddress,
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

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, deployments, getNamedAccounts } from 'hardhat';
import { verify } from '../utils/verify';
import { tokenAddresses, BASE_CHAIN_ID } from '../utils/constants';

const deployUSDTVault: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment
) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chainId = (await ethers.provider.getNetwork()).chainId;
  const waitConfirmations = chainId === BASE_CHAIN_ID ? 2 : 0;

  const name = 'Thesauros USDT';
  const symbol = 'tUSDT';

  const usdtAddress = tokenAddresses.USDT;

  log('----------------------------------------------------');
  log('Deploying USDT Thesauros Vault...');

  const [vaultManager, timelock, compoundV3Provider, aaveV3Provider] =
    await Promise.all([
      deployments.get('VaultManager'),
      deployments.get('Timelock'),
      deployments.get('CompoundV3Provider'),
      deployments.get('AaveV3Provider'),
    ]);

  const args = [
    usdtAddress,
    name,
    symbol,
    [compoundV3Provider.address, aaveV3Provider.address],
    ethers.parseEther('0.001'), // 0.1% withdrawal fee
    timelock.address,
    deployer, // treasury
  ];

  const usdtRebalancer = await deploy('USDTRebalancer', {
    contract: 'Rebalancer',
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: waitConfirmations,
  });

  log('----------------------------------------------------');
  log(`USDT Thesauros Vault at ${usdtRebalancer.address}`);

  if (chainId !== 31337) {
    await verify(usdtRebalancer.address, args);
  }
};

export default deployUSDTVault;
deployUSDTVault.tags = ['usdt-vault', 'vaults'];
deployUSDTVault.dependencies = [
  'timelock',
  'vault-manager',
  'aave-v3-provider',
  'compound-v3-provider',
];

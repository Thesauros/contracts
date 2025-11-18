import { ethers } from 'hardhat';
import { deployments } from 'hardhat';
import { verify } from '../utils/verify';

async function main() {
  const rebalancerDeployment = await deployments.get('Rebalancer');
  
  const usdcAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
  const name = 'Thesauros USDC Vault';
  const symbol = 'tUSDC';
  
  const aaveProvider = await deployments.get('AaveV3Provider');
  const compoundProvider = await deployments.get('CompoundV3Provider');
  const dolomiteProvider = await deployments.get('DolomiteProvider');
  const morphoProvider = await deployments.get('MorphoProvider');
  
  const providers = [
    aaveProvider.address,
    compoundProvider.address,
    dolomiteProvider.address,
    morphoProvider.address
  ];
  
  const timelock = await deployments.get('Timelock');
  const treasury = '0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D';
  const withdrawFeePercent = 0;
  
  const args = [
    usdcAddress,
    name,
    symbol,
    providers,
    withdrawFeePercent,
    timelock.address,
    treasury,
  ];
  
  console.log('Verifying Rebalancer...');
  console.log('Address:', rebalancerDeployment.address);
  console.log('Args:', args);
  
  await verify(rebalancerDeployment.address, args);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


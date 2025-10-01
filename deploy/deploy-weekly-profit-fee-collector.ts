import { ethers } from 'hardhat';
import { ConfigLoader } from '../utils/config';

async function main() {
  console.log('Deploying WeeklyProfitFeeCollector...');

  // Load configuration
  const configLoader = new ConfigLoader();
  const config = configLoader.loadConfig();
  
  if (!config) {
    console.error('Failed to load configuration');
    return;
  }

  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);
  console.log('Account balance:', (await deployer.provider.getBalance(deployer.address)).toString());

  // Get treasury address from config
  const treasuryAddress = config.baseContracts.Treasury?.address;
  if (!treasuryAddress) {
    console.error('Treasury address not found in config');
    return;
  }

  // Deploy WeeklyProfitFeeCollector
  const WeeklyProfitFeeCollector = await ethers.getContractFactory('WeeklyProfitFeeCollector');
  const weeklyProfitFeeCollector = await WeeklyProfitFeeCollector.deploy(treasuryAddress);
  await weeklyProfitFeeCollector.waitForDeployment();

  const weeklyProfitFeeCollectorAddress = await weeklyProfitFeeCollector.getAddress();
  console.log('WeeklyProfitFeeCollector deployed to:', weeklyProfitFeeCollectorAddress);

  // Register vaults with 25% profit fee (2500 basis points)
  const profitFeePercent = 2500; // 25%
  
  for (const [token, vault] of Object.entries(config.vaults)) {
    try {
      console.log(`Registering ${token} vault for profit fee collection...`);
      
      const tx = await weeklyProfitFeeCollector.registerVault(vault.address, profitFeePercent);
      await tx.wait();
      
      console.log(`✓ ${token} vault registered with ${profitFeePercent / 100}% profit fee`);
    } catch (error) {
      console.error(`✗ Failed to register ${token} vault:`, error);
    }
  }

  // Update config with new contract
  const newConfig = {
    ...config,
    baseContracts: {
      ...config.baseContracts,
      WeeklyProfitFeeCollector: {
        address: weeklyProfitFeeCollectorAddress,
        network: config.network
      }
    }
  };

  // Save updated config
  configLoader.saveConfig(newConfig);
  console.log('Configuration updated with WeeklyProfitFeeCollector address');

  console.log('\nDeployment Summary:');
  console.log('==================');
  console.log('WeeklyProfitFeeCollector:', weeklyProfitFeeCollectorAddress);
  console.log('Treasury:', treasuryAddress);
  console.log('Profit Fee Percent:', profitFeePercent / 100 + '%');
  console.log('Registered Vaults:', Object.keys(config.vaults).length);

  console.log('\nNext Steps:');
  console.log('===========');
  console.log('1. Verify contracts on block explorer');
  console.log('2. Set up monitoring for weekly fee collection');
  console.log('3. Register users for profit tracking');
  console.log('4. Test fee collection mechanism');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Deployment failed:', error);
    process.exit(1);
  });

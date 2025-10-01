import { ethers } from 'hardhat';
import { ConfigLoader } from '../utils/config';

async function main() {
  console.log('Setting up Weekly Profit Fee Collection System...');

  // Load configuration
  const configLoader = new ConfigLoader();
  const config = configLoader.loadConfig();
  
  if (!config) {
    console.error('Failed to load configuration');
    return;
  }

  const [deployer] = await ethers.getSigners();
  console.log('Using account:', deployer.address);

  // Get WeeklyProfitFeeCollector address
  const weeklyProfitFeeCollectorAddress = config.baseContracts.WeeklyProfitFeeCollector?.address;
  if (!weeklyProfitFeeCollectorAddress) {
    console.error('WeeklyProfitFeeCollector address not found in config');
    return;
  }

  const weeklyProfitFeeCollector = await ethers.getContractAt(
    'WeeklyProfitFeeCollector',
    weeklyProfitFeeCollectorAddress
  );

  console.log('WeeklyProfitFeeCollector address:', weeklyProfitFeeCollectorAddress);

  // Test user addresses (you can replace these with actual user addresses)
  const testUsers = [
    '0x1234567890123456789012345678901234567890',
    '0x2345678901234567890123456789012345678901',
    '0x3456789012345678901234567890123456789012'
  ];

  console.log('\nSetting up test users...');

  // Register test users for each vault
  for (const [token, vault] of Object.entries(config.vaults)) {
    console.log(`\nSetting up users for ${token} vault...`);
    
    for (const user of testUsers) {
      try {
        // Check if user is already registered
        const userInfo = await weeklyProfitFeeCollector.getUserInfo(vault.address, user);
        
        if (!userInfo.isRegistered) {
          console.log(`Registering user ${user} for ${token} vault...`);
          
          const tx = await weeklyProfitFeeCollector.registerUser(vault.address, user);
          await tx.wait();
          
          console.log(`✓ User ${user} registered for ${token} vault`);
        } else {
          console.log(`User ${user} already registered for ${token} vault`);
        }
      } catch (error) {
        console.error(`✗ Failed to register user ${user} for ${token} vault:`, error);
      }
    }
  }

  console.log('\nChecking vault configurations...');

  // Check vault configurations
  for (const [token, vault] of Object.entries(config.vaults)) {
    try {
      const vaultInfo = await weeklyProfitFeeCollector.getVaultInfo(vault.address);
      
      console.log(`\n${token} Vault Configuration:`);
      console.log(`  Address: ${vault.address}`);
      console.log(`  Registered: ${vaultInfo.isRegistered}`);
      console.log(`  Fee Percent: ${vaultInfo.feePercent / 100}%`);
      console.log(`  Collection Interval: ${vaultInfo.collectionInterval / 86400} days`);
      console.log(`  Total Fees Collected: ${ethers.formatUnits(vaultInfo.totalFeesCollected, 6)} tokens`);
      
    } catch (error) {
      console.error(`✗ Failed to get info for ${token} vault:`, error);
    }
  }

  console.log('\nChecking user readiness for fee collection...');

  // Check which users are ready for fee collection
  for (const [token, vault] of Object.entries(config.vaults)) {
    console.log(`\n${token} Vault - User Status:`);
    
    for (const user of testUsers) {
      try {
        const isReady = await weeklyProfitFeeCollector.isUserReadyForCollection(vault.address, user);
        const timeUntilNext = await weeklyProfitFeeCollector.getTimeUntilNextCollection(vault.address, user);
        const [profit, fee] = await weeklyProfitFeeCollector.calculateProfitFee(vault.address, user);
        
        console.log(`  User ${user}:`);
        console.log(`    Ready for collection: ${isReady}`);
        console.log(`    Time until next collection: ${timeUntilNext / 3600} hours`);
        console.log(`    Potential profit: ${ethers.formatUnits(profit, 6)} tokens`);
        console.log(`    Potential fee: ${ethers.formatUnits(fee, 6)} tokens`);
        
      } catch (error) {
        console.error(`    ✗ Error checking user ${user}:`, error);
      }
    }
  }

  console.log('\nTesting fee collection (if users are ready)...');

  // Test fee collection for ready users
  for (const [token, vault] of Object.entries(config.vaults)) {
    for (const user of testUsers) {
      try {
        const isReady = await weeklyProfitFeeCollector.isUserReadyForCollection(vault.address, user);
        
        if (isReady) {
          console.log(`\nCollecting fees for user ${user} in ${token} vault...`);
          
          const tx = await weeklyProfitFeeCollector.collectUserProfitFees(vault.address, user);
          const receipt = await tx.wait();
          
          console.log(`✓ Fee collection completed for user ${user}`);
          console.log(`  Gas used: ${receipt.gasUsed.toString()}`);
          
        } else {
          console.log(`User ${user} in ${token} vault not ready for collection yet`);
        }
        
      } catch (error) {
        console.error(`✗ Failed to collect fees for user ${user} in ${token} vault:`, error);
      }
    }
  }

  console.log('\nSetup completed!');
  console.log('\nNext Steps:');
  console.log('===========');
  console.log('1. Monitor user profits and fee collection');
  console.log('2. Set up automated fee collection scripts');
  console.log('3. Test with real user addresses');
  console.log('4. Configure monitoring and alerts');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Setup failed:', error);
    process.exit(1);
  });

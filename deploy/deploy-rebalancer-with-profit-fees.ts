import { ethers } from 'hardhat';
import { ConfigLoader } from '../utils/config';

async function main() {
  console.log('Deploying RebalancerWithProfitFees...');

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

  // Get required addresses from config
  const treasuryAddress = config.baseContracts.Treasury?.address;
  const timelockAddress = config.baseContracts.Timelock?.address;
  
  if (!treasuryAddress || !timelockAddress) {
    console.error('Required addresses not found in config');
    return;
  }

  // Get provider addresses
  const providerAddresses = Object.entries(config.baseContracts)
    .filter(([name]) => name.includes('Provider'))
    .map(([name, contract]) => contract.address);

  if (providerAddresses.length === 0) {
    console.error('No providers found in config');
    return;
  }

  console.log('Found providers:', providerAddresses);

  // Deploy RebalancerWithProfitFees for each vault
  const profitFeePercent = 2500; // 25% profit fee
  const withdrawFeePercent = 100; // 0.1% withdrawal fee (100 basis points)
  
  const deployedVaults: { [key: string]: string } = {};

  for (const [token, vault] of Object.entries(config.vaults)) {
    try {
      console.log(`\nDeploying RebalancerWithProfitFees for ${token}...`);
      
      // Get asset address from existing vault
      const existingVault = await ethers.getContractAt('Rebalancer', vault.address);
      const assetAddress = await existingVault.asset();
      
      console.log(`Asset address: ${assetAddress}`);
      
      // Deploy new RebalancerWithProfitFees
      const RebalancerWithProfitFees = await ethers.getContractFactory('RebalancerWithProfitFees');
      const rebalancerWithProfitFees = await RebalancerWithProfitFees.deploy(
        assetAddress,
        `${token} Vault with Profit Fees`,
        `${token}V`,
        providerAddresses,
        withdrawFeePercent,
        timelockAddress,
        treasuryAddress,
        profitFeePercent
      );
      
      await rebalancerWithProfitFees.waitForDeployment();
      const rebalancerAddress = await rebalancerWithProfitFees.getAddress();
      
      console.log(`✓ ${token} RebalancerWithProfitFees deployed to: ${rebalancerAddress}`);
      
      // Setup vault with initial deposit
      const setupAmount = ethers.parseUnits('1000', 6); // 1000 USDC
      console.log(`Setting up vault with ${ethers.formatUnits(setupAmount, 6)} ${token}...`);
      
      const setupTx = await rebalancerWithProfitFees.setupVault(setupAmount);
      await setupTx.wait();
      
      console.log(`✓ ${token} vault setup completed`);
      
      deployedVaults[token] = rebalancerAddress;
      
    } catch (error) {
      console.error(`✗ Failed to deploy ${token} RebalancerWithProfitFees:`, error);
    }
  }

  // Update config with new contracts
  const newConfig = {
    ...config,
    vaults: {
      ...config.vaults,
      ...Object.fromEntries(
        Object.entries(deployedVaults).map(([token, address]) => [
          `${token}WithProfitFees`,
          { address, network: config.network }
        ])
      )
    },
    baseContracts: {
      ...config.baseContracts,
      RebalancerWithProfitFees: {
        address: Object.values(deployedVaults)[0], // Store first deployed address as reference
        network: config.network
      }
    }
  };

  // Save updated config
  configLoader.saveConfig(newConfig);
  console.log('Configuration updated with RebalancerWithProfitFees addresses');

  console.log('\nDeployment Summary:');
  console.log('==================');
  console.log('Profit Fee Percent:', profitFeePercent / 100 + '%');
  console.log('Withdrawal Fee Percent:', withdrawFeePercent / 100 + '%');
  console.log('Treasury:', treasuryAddress);
  console.log('Timelock:', timelockAddress);
  console.log('\nDeployed Vaults:');
  Object.entries(deployedVaults).forEach(([token, address]) => {
    console.log(`${token}: ${address}`);
  });

  console.log('\nNext Steps:');
  console.log('===========');
  console.log('1. Verify contracts on block explorer');
  console.log('2. Test profit fee collection during rebalancing');
  console.log('3. Set up automated rebalancing with profit fees');
  console.log('4. Monitor fee collection and treasury balance');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Deployment failed:', error);
    process.exit(1);
  });

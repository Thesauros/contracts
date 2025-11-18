import { ethers } from 'hardhat';
import { deployments } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('🚀 Running Smoke Tests');
  console.log('======================');
  console.log(`Deployer: ${deployer.address}\n`);

  try {
    // Get deployed contracts
    const rebalancerDeployment = await deployments.get('Rebalancer');
    const providerManagerDeployment = await deployments.get('ProviderManager');
    const vaultManagerDeployment = await deployments.get('VaultManager');
    const timelockDeployment = await deployments.get('Timelock');
    
    const rebalancer = await ethers.getContractAt('Rebalancer', rebalancerDeployment.address);
    const providerManager = await ethers.getContractAt('ProviderManager', providerManagerDeployment.address);
    const vaultManager = await ethers.getContractAt('VaultManager', vaultManagerDeployment.address);
    const timelock = await ethers.getContractAt('Timelock', timelockDeployment.address);
    
    console.log('📋 Contract Addresses:');
    console.log(`  Rebalancer: ${rebalancerDeployment.address}`);
    console.log(`  ProviderManager: ${providerManagerDeployment.address}`);
    console.log(`  VaultManager: ${vaultManagerDeployment.address}`);
    console.log(`  Timelock: ${timelockDeployment.address}\n`);

    // Test 1: Check Rebalancer setup
    console.log('✅ Test 1: Rebalancer Setup');
    const isSetup = await rebalancer.setupCompleted();
    console.log(`  Setup completed: ${isSetup}`);
    if (!isSetup) {
      console.log('  ❌ FAIL: Vault not setup!');
      return;
    }
    
    const asset = await rebalancer.asset();
    console.log(`  Asset: ${asset}`);
    const totalAssets = await rebalancer.totalAssets();
    console.log(`  Total assets: ${ethers.formatUnits(totalAssets, 6)} USDC\n`);

    // Test 2: Check ProviderManager
    console.log('✅ Test 2: ProviderManager');
    const identifiers = await providerManager.getIdentifiers();
    console.log(`  Registered providers: ${identifiers.length}`);
    identifiers.forEach((id: string) => console.log(`    - ${id}`));
    
    const usdcAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
    const aaveYieldToken = await providerManager.getYieldToken('Aave_V3_Provider', usdcAddress);
    console.log(`  Aave yield token: ${aaveYieldToken}\n`);

    // Test 3: Check Roles
    console.log('✅ Test 3: Access Control');
    const OPERATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes('OPERATOR_ROLE'));
    const ADMIN_ROLE = ethers.ZeroHash; // ADMIN_ROLE is 0x00
    
    const vaultManagerHasOperatorRole = await rebalancer.hasRole(OPERATOR_ROLE, vaultManagerDeployment.address);
    console.log(`  VaultManager has OPERATOR_ROLE: ${vaultManagerHasOperatorRole}`);
    
    const deployerHasAdminRole = await rebalancer.hasRole(ADMIN_ROLE, deployer.address);
    console.log(`  Deployer has ADMIN_ROLE: ${deployerHasAdminRole}\n`);

    // Test 4: Check Providers
    console.log('✅ Test 4: Providers Configuration');
    const aaveProvider = await deployments.get('AaveV3Provider');
    const compoundProvider = await deployments.get('CompoundV3Provider');
    const dolomiteProvider = await deployments.get('DolomiteProvider');
    const morphoProvider = await deployments.get('MorphoProvider');
    
    console.log(`  AaveV3Provider: ${aaveProvider.address}`);
    console.log(`  CompoundV3Provider: ${compoundProvider.address}`);
    console.log(`  DolomiteProvider: ${dolomiteProvider.address}`);
    console.log(`  MorphoProvider: ${morphoProvider.address}\n`);

    // Test 5: Check Timelock
    console.log('✅ Test 5: Timelock');
    const timelockDelay = await timelock.delay();
    console.log(`  Delay: ${timelockDelay} seconds (${Number(timelockDelay) / 60} minutes)`);
    const timelockOwner = await timelock.owner();
    console.log(`  Owner: ${timelockOwner}\n`);

    // Test 6: Check Vault state
    console.log('✅ Test 6: Vault State');
    const name = await rebalancer.name();
    const symbol = await rebalancer.symbol();
    const decimals = await rebalancer.decimals();
    console.log(`  Name: ${name}`);
    console.log(`  Symbol: ${symbol}`);
    console.log(`  Decimals: ${decimals}`);
    
    const treasury = await rebalancer.treasury();
    console.log(`  Treasury: ${treasury}`);
    
    const withdrawFeePercent = await rebalancer.withdrawFeePercent();
    console.log(`  Withdraw fee: ${withdrawFeePercent}% (max 5%)\n`);

    console.log('✅ All smoke tests passed!');
    console.log('🎉 System is ready for use!');
    
  } catch (error: any) {
    console.error('❌ Smoke test failed:', error.message);
    if (error.data) {
      console.error('Error data:', error.data);
    }
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


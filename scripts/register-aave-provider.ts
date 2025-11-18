import { ethers } from 'hardhat';
import { deployments } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('🔧 Registering Aave Provider in ProviderManager');
  console.log('===============================================');
  console.log(`Deployer: ${deployer.address}\n`);

  try {
    const providerManagerDeployment = await deployments.get('ProviderManager');
    const providerManager = await ethers.getContractAt('ProviderManager', providerManagerDeployment.address);
    
    // Aave V3 Pool Addresses Provider on Arbitrum
    const aavePoolAddressesProvider = '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb';
    const aavePool = await ethers.getContractAt('IPoolAddressesProvider', aavePoolAddressesProvider);
    const poolAddress = await aavePool.getPool();
    
    // Get aToken address for USDC
    const usdcAddress = '0xaf88d065e77c8cC2239327C5EDb3A432268e5831';
    const pool = await ethers.getContractAt('IPool', poolAddress);
    const reserveData = await pool.getReserveData(usdcAddress);
    const aTokenAddress = reserveData.aTokenAddress;
    
    console.log(`Aave Pool: ${poolAddress}`);
    console.log(`USDC aToken: ${aTokenAddress}\n`);
    
    // Register Aave in ProviderManager
    const currentYieldToken = await providerManager.getYieldToken('Aave_V3_Provider', usdcAddress);
    if (currentYieldToken === ethers.ZeroAddress) {
      console.log('Registering Aave_V3_Provider...');
      const tx = await providerManager.setYieldToken(
        'Aave_V3_Provider',
        usdcAddress,
        aTokenAddress
      );
      await tx.wait();
      console.log(`✅ Registered Aave_V3_Provider with yield token: ${aTokenAddress}`);
    } else {
      console.log(`✅ Aave_V3_Provider already registered: ${currentYieldToken}`);
    }
    
    // Verify registration
    const identifiers = await providerManager.getIdentifiers();
    console.log(`\nRegistered providers: ${identifiers.length}`);
    identifiers.forEach((id: string) => console.log(`  - ${id}`));
    
    const aaveYieldToken = await providerManager.getYieldToken('Aave_V3_Provider', usdcAddress);
    console.log(`\nAave yield token: ${aaveYieldToken}`);
    
    console.log('\n✅ Aave provider registration completed!');
    
  } catch (error: any) {
    console.error('❌ Error:', error.message);
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


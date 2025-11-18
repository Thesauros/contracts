import { ethers } from 'hardhat';
import { deployments } from 'hardhat';
import { tokenAddresses, morphoVaults } from '../utils/constants';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('🔧 Setting up USDT Providers in ProviderManager');
  console.log('===============================================');
  console.log(`Deployer: ${deployer.address}\n`);

  try {
    const providerManagerDeployment = await deployments.get('ProviderManager');
    const providerManager = await ethers.getContractAt('ProviderManager', providerManagerDeployment.address);
    
    const usdtAddress = tokenAddresses.USDT;
    console.log(`USDT Address: ${usdtAddress}\n`);

    // 1. Setup Aave for USDT
    console.log('1️⃣ Setting up Aave_V3_Provider for USDT...');
    const aavePoolAddressesProvider = '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb';
    const aavePool = await ethers.getContractAt('IPoolAddressesProvider', aavePoolAddressesProvider);
    const poolAddress = await aavePool.getPool();
    const pool = await ethers.getContractAt('IPool', poolAddress);
    const reserveData = await pool.getReserveData(usdtAddress);
    const aTokenAddress = reserveData.aTokenAddress;
    
    const currentAaveYieldToken = await providerManager.getYieldToken('Aave_V3_Provider', usdtAddress);
    if (currentAaveYieldToken === ethers.ZeroAddress) {
      const tx = await providerManager.setYieldToken(
        'Aave_V3_Provider',
        usdtAddress,
        aTokenAddress
      );
      await tx.wait();
      console.log(`✅ Registered Aave_V3_Provider with yield token: ${aTokenAddress}`);
    } else {
      console.log(`✅ Aave_V3_Provider already registered: ${currentAaveYieldToken}`);
    }

    // 2. Setup Compound for USDT (should already be set from deploy-providers.ts)
    console.log('\n2️⃣ Checking Compound_V3_Provider for USDT...');
    const currentCompoundYieldToken = await providerManager.getYieldToken('Compound_V3_Provider', usdtAddress);
    if (currentCompoundYieldToken === ethers.ZeroAddress) {
      // Get cToken from constants
      const cometTokens = {
        cUSDT: '0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07',
      };
      const tx = await providerManager.setYieldToken(
        'Compound_V3_Provider',
        usdtAddress,
        cometTokens.cUSDT
      );
      await tx.wait();
      console.log(`✅ Registered Compound_V3_Provider with yield token: ${cometTokens.cUSDT}`);
    } else {
      console.log(`✅ Compound_V3_Provider already registered: ${currentCompoundYieldToken}`);
    }

    // 3. Setup Dolomite for USDT
    console.log('\n3️⃣ Setting up Dolomite_Provider for USDT...');
    const currentDolomiteYieldToken = await providerManager.getYieldToken('Dolomite_Provider', usdtAddress);
    if (currentDolomiteYieldToken === ethers.ZeroAddress) {
      const tx = await providerManager.setYieldToken(
        'Dolomite_Provider',
        usdtAddress,
        usdtAddress // Using asset address as yield token for Dolomite
      );
      await tx.wait();
      console.log(`✅ Registered Dolomite_Provider with yield token: ${usdtAddress}`);
    } else {
      console.log(`✅ Dolomite_Provider already registered: ${currentDolomiteYieldToken}`);
    }

    // 4. Setup Morpho for USDT
    console.log('\n4️⃣ Setting up Morpho_Provider for USDT...');
    const steakhouseVault = morphoVaults.find(
      (vault) => vault.strategy === 'Steakhouse Financial'
    );
    if (steakhouseVault) {
      const currentMorphoYieldToken = await providerManager.getYieldToken('Morpho_Provider', usdtAddress);
      if (currentMorphoYieldToken === ethers.ZeroAddress) {
        const tx = await providerManager.setYieldToken(
          'Morpho_Provider',
          usdtAddress,
          steakhouseVault.vaultAddress
        );
        await tx.wait();
        console.log(`✅ Registered Morpho_Provider with yield token: ${steakhouseVault.vaultAddress}`);
      } else {
        console.log(`✅ Morpho_Provider already registered: ${currentMorphoYieldToken}`);
      }
    } else {
      console.log('❌ Steakhouse Financial vault not found!');
    }

    // Verify all registrations
    console.log('\n📋 Verification:');
    const identifiers = await providerManager.getIdentifiers();
    console.log(`Registered providers: ${identifiers.length}`);
    identifiers.forEach((id: string) => console.log(`  - ${id}`));
    
    console.log('\n📊 USDT Yield Tokens:');
    const aaveToken = await providerManager.getYieldToken('Aave_V3_Provider', usdtAddress);
    const compoundToken = await providerManager.getYieldToken('Compound_V3_Provider', usdtAddress);
    const dolomiteToken = await providerManager.getYieldToken('Dolomite_Provider', usdtAddress);
    const morphoToken = await providerManager.getYieldToken('Morpho_Provider', usdtAddress);
    
    console.log(`  Aave: ${aaveToken}`);
    console.log(`  Compound: ${compoundToken}`);
    console.log(`  Dolomite: ${dolomiteToken}`);
    console.log(`  Morpho: ${morphoToken}`);
    
    console.log('\n✅ All USDT providers configured!');
    
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


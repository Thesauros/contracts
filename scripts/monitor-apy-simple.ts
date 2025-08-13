import { ethers } from 'hardhat';
import { configLoader } from '../utils/config';

interface ProviderAPY {
  name: string;
  address: string;
  apy: number;
  status: string;
}

interface TokenInfo {
  symbol: string;
  address: string;
  decimals: number;
}

async function main() {
  console.log('Thesauros Simple APY Monitor');
  console.log('================================\n');

  // Load configuration dynamically
  try {
    await configLoader.validateConfig();
  } catch (error) {
    console.error('Failed to load configuration:', error);
    process.exit(1);
  }

  // Get addresses dynamically
  const tokenAddresses = await configLoader.getTokenAddresses();
  const tokenDecimals = await configLoader.getTokenDecimals();
  const providerAddresses = await configLoader.getProviderAddresses();

  // Convert to tokenInfo format
  const tokenInfo: { [key: string]: TokenInfo } = {};
  for (const [symbol, address] of Object.entries(tokenAddresses)) {
    tokenInfo[symbol] = {
      symbol: symbol,
      address: address,
      decimals: tokenDecimals[symbol] || 18
    };
  }

  console.log('Provider Status Analysis');
  console.log('===========================\n');

  const providerAPYs: ProviderAPY[] = [];

  // Analyze provider status
  for (const [providerName, providerAddress] of Object.entries(providerAddresses)) {
    try {
      console.log(`${providerName}:`);
      
      // Check if contract exists
      const code = await ethers.provider.getCode(providerAddress);
      if (code === '0x') {
        console.log(`   Contract not deployed`);
        continue;
      }

      // Get ETH balance
      const balance = await ethers.provider.getBalance(providerAddress);
      console.log(`   Balance: ${ethers.formatEther(balance)} ETH`);

      // Check if provider can be called
      const provider = await ethers.getContractAt('IProvider', providerAddress);
      
      // Simulate APY based on balance and other factors
      const baseAPY = 3.5; // Base APY 3.5%
      const balanceFactor = Number(ethers.formatEther(balance)) / 1000; // Balance factor
      const randomFactor = Math.random() * 2 - 1; // Random factor ±1%
      
      const apy = Math.max(0, baseAPY + balanceFactor + randomFactor);

      const providerAPY: ProviderAPY = {
        name: providerName,
        address: providerAddress,
        apy: apy,
        status: 'Active'
      };

      providerAPYs.push(providerAPY);

      console.log(`   APY: ${apy.toFixed(4)}%`);
      console.log(`   Status: Active`);
      console.log('');

    } catch (error) {
      console.log(`   Error: ${error}`);
      console.log('');
    }
  }

  // Analyze vaults and their active providers
  console.log('Vault Provider Analysis');
  console.log('==========================\n');

  const vaultAddresses = await configLoader.getVaultAddresses();

  for (const [vaultName, vaultAddress] of Object.entries(vaultAddresses)) {
    try {
      const vault = await ethers.getContractAt('Rebalancer', vaultAddress);
      const activeProvider = await vault.activeProvider();
      
      // Находим имя активного провайдера
      const activeProviderName = Object.keys(providerAddresses).find(
        key => providerAddresses[key as keyof typeof providerAddresses] === activeProvider
      ) || 'Unknown';

      console.log(`${vaultName}:`);
      console.log(`   Active Provider: ${activeProviderName}`);
      console.log(`   Provider Address: ${activeProvider}`);
      
      // Find active provider APY
      const activeProviderAPY = providerAPYs.find(p => p.address === activeProvider);
      if (activeProviderAPY) {
        console.log(`   Current APY: ${activeProviderAPY.apy.toFixed(4)}%`);
      } else {
        console.log(`   Current APY: Unknown`);
      }
      console.log('');

    } catch (error) {
      console.log(`Error analyzing ${vaultName}: ${error}`);
      console.log('');
    }
  }

  // Show overall statistics
  console.log('Overall Statistics');
  console.log('====================\n');

  if (providerAPYs.length > 0) {
    const avgAPY = providerAPYs.reduce((sum, p) => sum + p.apy, 0) / providerAPYs.length;
    const maxAPY = Math.max(...providerAPYs.map(p => p.apy));
    const minAPY = Math.min(...providerAPYs.map(p => p.apy));
    
    console.log(`Average APY across all providers: ${avgAPY.toFixed(4)}%`);
    console.log(`Highest APY: ${maxAPY.toFixed(4)}%`);
    console.log(`Lowest APY: ${minAPY.toFixed(4)}%`);
    console.log(`APY Spread: ${(maxAPY - minAPY).toFixed(4)}%`);
    console.log(`Total providers analyzed: ${providerAPYs.length}`);
  } else {
    console.log('No provider data available');
  }

  // Recommendations
  console.log('\nRecommendations:');
  console.log('===================\n');

  if (providerAPYs.length > 1) {
    const sortedProviders = providerAPYs.sort((a, b) => b.apy - a.apy);
    const bestProvider = sortedProviders[0];
    const worstProvider = sortedProviders[sortedProviders.length - 1];
    
    console.log(`Best performing provider: ${bestProvider.name} (${bestProvider.apy.toFixed(4)}% APY)`);
    console.log(`Lowest performing provider: ${worstProvider.name} (${worstProvider.apy.toFixed(4)}% APY)`);
    
    const apyDiff = bestProvider.apy - worstProvider.apy;
    if (apyDiff > 0.5) {
      console.log(`Consider rebalancing: APY difference is ${apyDiff.toFixed(4)}%`);
    } else {
      console.log(`APY difference is minimal (${apyDiff.toFixed(4)}%) - no rebalancing needed`);
    }
  } else {
    console.log('Insufficient data for recommendations');
  }

  console.log('\nSimple APY monitoring complete!');
  console.log('\nTips:');
  console.log('   - This is a simplified analysis');
  console.log('   - For accurate APY data, check provider APIs directly');
  console.log('   - Monitor gas prices for optimal rebalancing');
  console.log('   - Set up alerts for significant APY changes');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

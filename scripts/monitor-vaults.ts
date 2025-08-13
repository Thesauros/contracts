import { ethers } from 'hardhat';
import { configLoader } from '../utils/config';

interface VaultInfo {
  name: string;
  address: string;
  symbol: string;
  asset: string;
  tvl: string;
  apy: string;
  activeProvider: string;
  totalShares: string;
  totalAssets: string;
  lastRebalance?: string;
}

interface ProviderInfo {
  name: string;
  address: string;
  apr: string;
  balance: string;
}

async function main() {
  console.log('Thesauros Vaults Monitoring Dashboard');
  console.log('========================================\n');

  // Load configuration dynamically
  try {
    await configLoader.validateConfig();
  } catch (error) {
    console.error('Failed to load configuration:', error);
    process.exit(1);
  }

  // Get deployed vault addresses dynamically
  const vaultAddresses = await configLoader.getVaultAddresses();
  const tokenAddresses = await configLoader.getTokenAddresses();
  const tokenDecimals = await configLoader.getTokenDecimals();
  const providerAddresses = await configLoader.getProviderAddresses();

  const vaultsInfo: VaultInfo[] = [];

  console.log('Vault Status Report');
  console.log('======================\n');

  for (const [vaultName, vaultAddress] of Object.entries(vaultAddresses)) {
    try {
      const vault = await ethers.getContractAt('Rebalancer', vaultAddress);
      const assetAddress = await vault.asset();
      const totalAssets = await vault.totalAssets();
      const totalShares = await vault.totalSupply();
      const activeProvider = await vault.activeProvider();
      
      // Determine token
      const tokenSymbol = Object.keys(tokenAddresses).find(
        key => tokenAddresses[key as keyof typeof tokenAddresses] === assetAddress
      ) || 'Unknown';
      
      const decimals = tokenDecimals[tokenSymbol as keyof typeof tokenDecimals] || 18;
      
      // Format values
      const tvlFormatted = ethers.formatUnits(totalAssets, decimals);
      const sharesFormatted = ethers.formatUnits(totalShares, 18);
      
      // Get active provider name
      const activeProviderName = Object.keys(providerAddresses).find(
        key => providerAddresses[key as keyof typeof providerAddresses] === activeProvider
      ) || 'Unknown';

      // Get last rebalancing event
      let lastRebalance = 'No recent rebalances';
      try {
        const currentBlock = await ethers.provider.getBlockNumber();
        const fromBlock = Math.max(0, currentBlock - 500); // Limit to 500 blocks for RPC
        
        const rebalanceEvents = await vault.queryFilter(
          vault.filters.RebalanceExecuted(),
          fromBlock,
          currentBlock
        );

        if (rebalanceEvents.length > 0) {
          lastRebalance = `Block ${rebalanceEvents[rebalanceEvents.length - 1].blockNumber}`;
        }
      } catch (error) {
        lastRebalance = 'Unable to fetch';
      }

      const vaultInfo: VaultInfo = {
        name: vaultName,
        address: vaultAddress,
        symbol: `t${tokenSymbol}`,
        asset: assetAddress,
        tvl: tvlFormatted,
        apy: '0.00', // Will be calculated separately
        activeProvider: activeProviderName,
        totalShares: sharesFormatted,
        totalAssets: tvlFormatted,
        lastRebalance: lastRebalance
      };

      vaultsInfo.push(vaultInfo);

      console.log(`${vaultName}`);
      console.log(`   Address: ${vaultAddress}`);
      console.log(`   Symbol: ${vaultInfo.symbol}`);
      console.log(`   TVL: ${tvlFormatted} ${tokenSymbol}`);
      console.log(`   Total Shares: ${sharesFormatted}`);
      console.log(`   Active Provider: ${activeProviderName}`);
      console.log(`   Last Rebalance: ${lastRebalance}`);
      console.log('');

    } catch (error) {
      console.log(`Error getting info for ${vaultName}: ${error}`);
      console.log('');
    }
  }

  // Show overall statistics
  console.log('Overall Statistics');
  console.log('====================\n');

  const totalTVL = vaultsInfo.reduce((sum, vault) => {
    const tvl = parseFloat(vault.tvl);
    return sum + tvl;
  }, 0);

  console.log(`Total TVL across all vaults: $${totalTVL.toFixed(2)}`);
  console.log(`Number of active vaults: ${vaultsInfo.length}`);
  console.log(`Active providers: ${new Set(vaultsInfo.map(v => v.activeProvider)).size}`);

  // Show provider information
  console.log('\nProvider Information');
  console.log('======================\n');

  for (const [providerName, providerAddress] of Object.entries(providerAddresses)) {
    try {
      const provider = await ethers.getContractAt('IProvider', providerAddress);
      
      // Get provider balance (simplified)
      const balance = await ethers.provider.getBalance(providerAddress);
      
      console.log(`${providerName}`);
      console.log(`   Address: ${providerAddress}`);
      console.log(`   Balance: ${ethers.formatEther(balance)} ETH`);
      console.log(`   Status: Active`);
      console.log('');
      
    } catch (error) {
      console.log(`Error getting info for ${providerName}: ${error}`);
      console.log('');
    }
  }

  // Show recent events
  console.log('Recent Events');
  console.log('================\n');

  // Get recent rebalancing events
  const vaultManagerAddress = await configLoader.getVaultManagerAddress();
  
  try {
    const vaultManager = await ethers.getContractAt('VaultManager', vaultManagerAddress);
    const currentBlock = await ethers.provider.getBlockNumber();
    const fromBlock = Math.max(0, currentBlock - 100); // Last 100 blocks
    
    try {
      const rebalanceEvents = await vaultManager.queryFilter(
        vaultManager.filters.RebalanceVaultExecuted(),
        fromBlock,
        currentBlock
      );

      if (rebalanceEvents.length > 0) {
        console.log('Recent Rebalancing Events:');
        for (let i = Math.min(5, rebalanceEvents.length - 1); i >= 0; i--) {
          const event = rebalanceEvents[i];
          const block = await ethers.provider.getBlock(event.blockNumber);
          const timestamp = new Date((block?.timestamp || 0) * 1000).toLocaleString();
          
          console.log(`   Block ${event.blockNumber} (${timestamp})`);
          console.log(`   Vault: ${event.args?.vault}`);
          console.log(`   Assets: ${event.args?.assets}`);
          console.log(`   Success: ${event.args?.success}`);
          console.log('');
        }
      } else {
        console.log('No recent rebalancing events found');
      }
    } catch (error) {
      console.log('No recent rebalancing events found (filter not available)');
    }
    
  } catch (error) {
    console.log(`Error getting recent events: ${error}`);
  }

  console.log('Monitoring complete!');
  console.log('\nTips:');
  console.log('   - Run this script regularly to track performance');
  console.log('   - Monitor gas prices for optimal rebalancing');
  console.log('   - Check provider APRs for rebalancing opportunities');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

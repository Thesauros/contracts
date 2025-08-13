import { ethers } from 'hardhat';

interface ProviderAPY {
  name: string;
  address: string;
  apr: number;
  apy: number;
  totalSupply: string;
  utilization: number;
}

interface TokenInfo {
  symbol: string;
  address: string;
  decimals: number;
}

async function main() {
  console.log(' Thesauros Provider APY Monitoring');
  console.log('====================================\n');

  const tokenInfo: { [key: string]: TokenInfo } = {
    'WETH': {
      symbol: 'WETH',
      address: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
      decimals: 18
    },
    'USDC': {
      symbol: 'USDC',
      address: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
      decimals: 6
    },
    'USDT': {
      symbol: 'USDT',
      address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
      decimals: 6
    },
    'DAI': {
      symbol: 'DAI',
      address: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
      decimals: 18
    }
  };

  const providerAddresses = {
    'AaveV3Provider': '0xE1Cfb1BDb3901dcEe9F21146c1F299c775d9B65C',
    'CompoundV3Provider': '0x4382190FDbf4befA016Ea412f34eb54593312aD5'
  };

  // Aave V3 Pool Addresses Provider
  const aaveAddressesProvider = '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb';
  
  // Compound V3 Comet addresses
  const compoundCometAddresses = {
    'USDC': '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf',
    'USDT': '0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07',
    'WETH': '0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486'
  };

  console.log(' Provider APY Analysis');
  console.log('========================\n');

  const providerAPYs: ProviderAPY[] = [];

  // Анализируем Aave V3
  console.log(' Aave V3 Provider Analysis');
  console.log('-----------------------------\n');

  try {
    const aaveProvider = await ethers.getContractAt('AaveV3Provider', providerAddresses.AaveV3Provider);
    
    for (const [tokenSymbol, token] of Object.entries(tokenInfo)) {
      try {
        // Получаем резервные данные из Aave
        const aavePool = await ethers.getContractAt('IPool', '0x794a61358D6845594F94dc1DB02A252b5b4814aD');
        const reserveData = await aavePool.getReserveData(token.address);
        
        // Рассчитываем APY
        const liquidityRate = Number(reserveData.currentLiquidityRate);
        const apr = liquidityRate / 1e27; // Aave использует RAY (27 decimals)
        const apy = (Math.pow(1 + apr / 365, 365) - 1) * 100;
        
        const totalSupply = ethers.formatUnits(reserveData.currentATokenBalance, token.decimals);
        const totalBorrow = ethers.formatUnits(reserveData.currentVariableDebt, token.decimals);
        const utilization = totalBorrow > 0 ? (Number(totalBorrow) / (Number(totalSupply) + Number(totalBorrow))) * 100 : 0;

        const providerAPY: ProviderAPY = {
          name: `Aave V3 - ${tokenSymbol}`,
          address: providerAddresses.AaveV3Provider,
          apr: apr * 100,
          apy: apy,
          totalSupply: totalSupply,
          utilization: utilization
        };

        providerAPYs.push(providerAPY);

        console.log(` ${tokenSymbol}:`);
        console.log(`   APR: ${(apr * 100).toFixed(4)}%`);
        console.log(`   APY: ${apy.toFixed(4)}%`);
        console.log(`   Total Supply: ${totalSupply} ${tokenSymbol}`);
        console.log(`   Utilization: ${utilization.toFixed(2)}%`);
        console.log('');

      } catch (error) {
        console.log(`  Error getting Aave data for ${tokenSymbol}: ${error}`);
        console.log('');
      }
    }

  } catch (error) {
    console.log(`  Error analyzing Aave V3: ${error}`);
    console.log('');
  }

  // Анализируем Compound V3
  console.log(' Compound V3 Provider Analysis');
  console.log('--------------------------------\n');

  try {
    const compoundProvider = await ethers.getContractAt('CompoundV3Provider', providerAddresses.CompoundV3Provider);
    
    for (const [tokenSymbol, cometAddress] of Object.entries(compoundCometAddresses)) {
      try {
        const token = tokenInfo[tokenSymbol];
        if (!token) continue;

        const comet = await ethers.getContractAt('CometInterface', cometAddress);
        
        // Получаем базовую ставку
        const baseRate = await comet.baseRate();
        const baseRatePerYear = Number(baseRate) / 1e9; // Compound использует 9 decimals
        
        // Получаем ставку за утилизацию
        const utilizationRate = await comet.getUtilizationRate();
        const utilizationRateNum = Number(utilizationRate) / 1e18;
        
        // Получаем множитель ставки
        const rateMultiplier = await comet.rateMultiplier();
        const rateMultiplierNum = Number(rateMultiplier) / 1e9;
        
        // Рассчитываем APR
        const apr = baseRatePerYear + (utilizationRateNum * rateMultiplierNum);
        const apy = (Math.pow(1 + apr / 365, 365) - 1) * 100;
        
        // Получаем общий supply
        const totalSupply = await comet.totalSupply();
        const totalBorrow = await comet.totalBorrow();
        
        const totalSupplyFormatted = ethers.formatUnits(totalSupply, token.decimals);
        const totalBorrowFormatted = ethers.formatUnits(totalBorrow, token.decimals);
        const utilization = totalBorrow > 0 ? (Number(totalBorrowFormatted) / Number(totalSupplyFormatted)) * 100 : 0;

        const providerAPY: ProviderAPY = {
          name: `Compound V3 - ${tokenSymbol}`,
          address: providerAddresses.CompoundV3Provider,
          apr: apr * 100,
          apy: apy,
          totalSupply: totalSupplyFormatted,
          utilization: utilization
        };

        providerAPYs.push(providerAPY);

        console.log(` ${tokenSymbol}:`);
        console.log(`   APR: ${(apr * 100).toFixed(4)}%`);
        console.log(`   APY: ${apy.toFixed(4)}%`);
        console.log(`   Total Supply: ${totalSupplyFormatted} ${tokenSymbol}`);
        console.log(`   Utilization: ${utilization.toFixed(2)}%`);
        console.log('');

      } catch (error) {
        console.log(`  Error getting Compound data for ${tokenSymbol}: ${error}`);
        console.log('');
      }
    }

  } catch (error) {
    console.log(`  Error analyzing Compound V3: ${error}`);
    console.log('');
  }

  // Сравнительный анализ
  console.log(' Comparative Analysis');
  console.log('======================\n');

  // Группируем по токенам
  const tokenGroups: { [key: string]: ProviderAPY[] } = {};
  
  for (const apy of providerAPYs) {
    const tokenSymbol = apy.name.split(' - ')[1];
    if (!tokenGroups[tokenSymbol]) {
      tokenGroups[tokenSymbol] = [];
    }
    tokenGroups[tokenSymbol].push(apy);
  }

  for (const [tokenSymbol, providers] of Object.entries(tokenGroups)) {
    console.log(` ${tokenSymbol} Providers Comparison:`);
    console.log('----------------------------------------');
    
    // Сортируем по APY
    const sortedProviders = providers.sort((a, b) => b.apy - a.apy);
    
    for (const provider of sortedProviders) {
      const providerName = provider.name.split(' - ')[0];
      console.log(`   ${providerName}: ${provider.apy.toFixed(4)}% APY`);
    }
    
    // Рекомендация
    const bestProvider = sortedProviders[0];
    const bestProviderName = bestProvider.name.split(' - ')[0];
    console.log(`    Best: ${bestProviderName} (${bestProvider.apy.toFixed(4)}% APY)`);
    console.log('');
  }

  // Общая статистика
  console.log(' Overall Statistics');
  console.log('====================\n');

  const avgAPY = providerAPYs.reduce((sum, p) => sum + p.apy, 0) / providerAPYs.length;
  const maxAPY = Math.max(...providerAPYs.map(p => p.apy));
  const minAPY = Math.min(...providerAPYs.map(p => p.apy));
  
  console.log(`Average APY across all providers: ${avgAPY.toFixed(4)}%`);
  console.log(`Highest APY: ${maxAPY.toFixed(4)}%`);
  console.log(`Lowest APY: ${minAPY.toFixed(4)}%`);
  console.log(`APY Spread: ${(maxAPY - minAPY).toFixed(4)}%`);
  console.log(`Total providers analyzed: ${providerAPYs.length}`);

  // Рекомендации по ребалансировке
  console.log('\n Rebalancing Recommendations');
  console.log('==============================\n');

  for (const [tokenSymbol, providers] of Object.entries(tokenGroups)) {
    if (providers.length > 1) {
      const sorted = providers.sort((a, b) => b.apy - a.apy);
      const best = sorted[0];
      const worst = sorted[sorted.length - 1];
      const apyDiff = best.apy - worst.apy;
      
      if (apyDiff > 0.5) { // Если разница больше 0.5%
        console.log(`Tips ${tokenSymbol}: Consider rebalancing from ${worst.name.split(' - ')[0]} to ${best.name.split(' - ')[0]}`);
        console.log(`   Potential gain: ${apyDiff.toFixed(4)}% APY`);
        console.log('');
      }
    }
  }

  console.log('  APY monitoring complete!');
  console.log('\nTips Tips:');
  console.log('   - Monitor APY changes regularly');
  console.log('   - Consider gas costs when rebalancing');
  console.log('   - Set up alerts for significant APY changes');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

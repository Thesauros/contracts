import { ethers } from 'hardhat';
import { ConfigLoader } from '../utils/config';

interface RealAPYData {
  provider: string;
  token: string;
  apy: number;
  source: string;
  timestamp: number;
}

interface APYSource {
  name: string;
  url: string;
  description: string;
}

async function main() {
  console.log('Thesauros Real APY Data Monitor');
  console.log('===================================\n');

  // Real APY data sources
  const apySources: APYSource[] = [
    {
      name: 'DefiLlama API',
      url: 'https://api.llama.fi/protocols',
      description: 'Aggregated DeFi protocol data'
    },
    {
      name: 'Aave API',
      url: 'https://api.aave.com/v3/protocol-data',
      description: 'Official Aave protocol data'
    },
    {
      name: 'Compound API',
      url: 'https://api.compound.finance/api/v2/ctoken',
      description: 'Official Compound protocol data'
    },
    {
      name: 'DeFi Pulse API',
      url: 'https://api.defipulse.com/v1/defipulse.json',
      description: 'DeFi protocol analytics'
    }
  ];

  console.log('Available APY Data Sources:');
  console.log('================================\n');

  for (const source of apySources) {
    console.log(`${source.name}`);
    console.log(`   URL: ${source.url}`);
    console.log(`   Description: ${source.description}`);
    console.log('');
  }

  // Load configuration dynamically
  const configLoader = new ConfigLoader();
  
  try {
    await configLoader.validateConfig();
  } catch (error) {
    console.error('Failed to load configuration:', error);
    process.exit(1);
  }

  // Get tokens and providers dynamically
  const tokens = await configLoader.getTokenAddresses();
  const baseContracts = await configLoader.getBaseContractAddresses();
  
  const providers = {
    'Aave V3': baseContracts.AaveV3Provider || '0x794a61358D6845594F94dc1DB02A252b5b4814aD',
    'Compound V3': baseContracts.CompoundV3Provider || '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf'
  };

  console.log('Attempting to fetch real APY data...');
  console.log('========================================\n');

  const realAPYData: RealAPYData[] = [];

  // 1. Attempt to get data from DefiLlama API
  console.log('Fetching from DefiLlama API...');
  try {
    const response = await fetch('https://api.llama.fi/protocols');
    if (response.ok) {
      const data = await response.json();
      
      // Ищем Aave и Compound в данных
      const aaveData = data.find((p: any) => p.name.toLowerCase().includes('aave'));
      const compoundData = data.find((p: any) => p.name.toLowerCase().includes('compound'));
      
      if (aaveData) {
        console.log(`   Aave found: ${aaveData.name}`);
        console.log(`   TVL: $${(aaveData.tvl / 1e6).toFixed(2)}M`);
        // DefiLlama doesn't provide APY directly, but we can use TVL as an indicator
      }
      
      if (compoundData) {
        console.log(`   Compound found: ${compoundData.name}`);
        console.log(`   TVL: $${(compoundData.tvl / 1e6).toFixed(2)}M`);
      }
    }
  } catch (error) {
    console.log(`   Error fetching from DefiLlama: ${error}`);
  }

  // 2. Attempt to get data from Aave API
  console.log('\nFetching from Aave API...');
  try {
    const response = await fetch('https://api.aave.com/v3/protocol-data');
    if (response.ok) {
      const data = await response.json();
      console.log(`   Aave API response received`);
      console.log(`   Data keys: ${Object.keys(data).join(', ')}`);
      
      // Parse Aave data
      if (data.reservesData) {
        for (const [tokenSymbol, tokenAddress] of Object.entries(tokens)) {
          const reserveData = (data.reservesData as any)[tokenAddress];
          if (reserveData) {
            const liquidityRate = Number(reserveData.currentLiquidityRate) / 1e27;
            const apy = (Math.pow(1 + liquidityRate / 365, 365) - 1) * 100;
            
            realAPYData.push({
              provider: 'Aave V3',
              token: tokenSymbol,
              apy: apy,
              source: 'Aave API',
              timestamp: Date.now()
            });
            
            console.log(`   ${tokenSymbol}: ${apy.toFixed(4)}% APY`);
          }
        }
      }
    }
  } catch (error) {
    console.log(`   Error fetching from Aave API: ${error}`);
  }

  // 3. Attempt to get data from Compound API
  console.log('\nFetching from Compound API...');
  try {
    const response = await fetch('https://api.compound.finance/api/v2/ctoken');
    if (response.ok) {
      const data = await response.json();
      console.log(`   Compound API response received`);
      console.log(`   Number of cTokens: ${data.cToken.length}`);
      
      // Parse Compound data
      for (const cToken of data.cToken) {
        if (cToken.supply_rate && cToken.symbol) {
          const apy = Number(cToken.supply_rate.value) * 100;
          
          realAPYData.push({
            provider: 'Compound V3',
            token: cToken.symbol,
            apy: apy,
            source: 'Compound API',
            timestamp: Date.now()
          });
          
          console.log(`   ${cToken.symbol}: ${apy.toFixed(4)}% APY`);
        }
      }
    }
  } catch (error) {
    console.log(`   Error fetching from Compound API: ${error}`);
  }

  // 4. Attempt to get data directly from smart contracts
  console.log('\nFetching from smart contracts...');
  
  for (const [providerName, providerAddress] of Object.entries(providers)) {
    try {
      if (providerName === 'Aave V3') {
        const aavePool = await ethers.getContractAt('IPool', providerAddress);
        
        for (const [tokenSymbol, tokenAddress] of Object.entries(tokens)) {
          try {
            const reserveData = await aavePool.getReserveData(tokenAddress as any);
            const liquidityRate = Number(reserveData.currentLiquidityRate) / 1e27;
            const apy = (Math.pow(1 + liquidityRate / 365, 365) - 1) * 100;
            
            realAPYData.push({
              provider: providerName,
              token: tokenSymbol,
              apy: apy,
              source: 'Smart Contract',
              timestamp: Date.now()
            });
            
            console.log(`   ${providerName} - ${tokenSymbol}: ${apy.toFixed(4)}% APY`);
          } catch (error) {
            console.log(`   Error getting ${tokenSymbol} data: ${error}`);
          }
        }
      }
    } catch (error) {
      console.log(`   Error accessing ${providerName} contract: ${error}`);
    }
  }

  // Show results
  console.log('\nReal APY Data Summary');
  console.log('=========================\n');

  if (realAPYData.length > 0) {
    // Group by tokens
    const tokenGroups: { [key: string]: RealAPYData[] } = {};
    
    for (const data of realAPYData) {
      if (!tokenGroups[data.token]) {
        tokenGroups[data.token] = [];
      }
      tokenGroups[data.token].push(data);
    }

    for (const [token, dataArray] of Object.entries(tokenGroups)) {
      console.log(`${token} APY Data:`);
      console.log('─'.repeat(30));
      
      for (const data of dataArray) {
        console.log(`   ${data.provider}: ${data.apy.toFixed(4)}% (${data.source})`);
      }
      
      // Find best APY for token
      const bestAPY = Math.max(...dataArray.map(d => d.apy));
      const bestProvider = dataArray.find(d => d.apy === bestAPY);
      
      console.log(`   Best: ${bestProvider?.provider} (${bestAPY.toFixed(4)}%)`);
      console.log('');
    }

    // Overall statistics
    const avgAPY = realAPYData.reduce((sum, d) => sum + d.apy, 0) / realAPYData.length;
    const maxAPY = Math.max(...realAPYData.map(d => d.apy));
    const minAPY = Math.min(...realAPYData.map(d => d.apy));
    
    console.log('Overall Statistics:');
    console.log('=====================');
    console.log(`Average APY: ${avgAPY.toFixed(4)}%`);
    console.log(`Highest APY: ${maxAPY.toFixed(4)}%`);
    console.log(`Lowest APY: ${minAPY.toFixed(4)}%`);
    console.log(`APY Spread: ${(maxAPY - minAPY).toFixed(4)}%`);
    console.log(`Total data points: ${realAPYData.length}`);
    console.log(`Data sources: ${new Set(realAPYData.map(d => d.source)).size}`);

  } else {
    console.log('No real APY data could be fetched');
    console.log('\nPossible reasons:');
    console.log('   - Network connectivity issues');
    console.log('   - API rate limits');
    console.log('   - Contract access issues');
    console.log('   - Protocol changes');
  }

  console.log('\nReal APY monitoring complete!');
  console.log('\nTips:');
  console.log('   - Real data may vary significantly from simulated data');
  console.log('   - API responses can be delayed or unavailable');
  console.log('   - Consider using multiple data sources for accuracy');
  console.log('   - Monitor API rate limits and costs');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

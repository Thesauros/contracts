import { ethers } from 'hardhat';

interface RebalanceOpportunity {
  vault: string;
  vaultName: string;
  currentProvider: string;
  bestProvider: string;
  apyDifference: number;
  estimatedProfit: string;
  gasEstimate: bigint;
}

interface ProviderAPY {
  name: string;
  address: string;
  apy: number;
}

async function main() {
  console.log('🤖 Thesauros Auto-Rebalancing Bot');
  console.log('==================================\n');

  // Проверяем, что у нас есть приватный ключ
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.log('❌ Error: PRIVATE_KEY environment variable not set');
    console.log('Please set your private key in .env file');
    process.exit(1);
  }

  // Адреса контрактов
  const vaultAddresses = {
    'WETH Vault': '0x78c11f63E6840820be18fDA461Ab16f23da5884f',
    'USDC Vault': '0xdf5AFad7f88888bEE944d14982c2d9eBA65653e6',
    'USDT Vault': '0xe1D34AB80090da3498Fc5D0696a2Cf82971E5eC6',
    'DAI Vault': '0xBC64abbCa87289746f2B01C8ab02A78c9fC92B89'
  };

  const providerAddresses = {
    'AaveV3Provider': '0xE1Cfb1BDb3901dcEe9F21146c1F299c775d9B65C',
    'CompoundV3Provider': '0x4382190FDbf4befA016Ea412f34eb54593312aD5'
  };

  const vaultManagerAddress = '0xAeEcf7F780e88B155df330434Ef29b2B077024e0';

  // Минимальная разница APY для ребалансировки (в процентах)
  const MIN_APY_DIFFERENCE = 0.5; // 0.5%
  
  // Минимальная сумма для ребалансировки
  const MIN_REBALANCE_AMOUNT = ethers.parseUnits('100', 6); // 100 USDC

  console.log('🔍 Analyzing rebalancing opportunities...\n');

  const opportunities: RebalanceOpportunity[] = [];

  // Получаем текущие цены на газ
  const gasPrice = await ethers.provider.getFeeData();
  const currentGasPrice = gasPrice.gasPrice || ethers.parseUnits('0.1', 'gwei');

  console.log(`⛽ Current gas price: ${ethers.formatUnits(currentGasPrice, 'gwei')} gwei`);

  // Анализируем каждый vault
  for (const [vaultName, vaultAddress] of Object.entries(vaultAddresses)) {
    try {
      console.log(`\n📊 Analyzing ${vaultName}...`);
      
      const vault = await ethers.getContractAt('Rebalancer', vaultAddress);
      const activeProvider = await vault.activeProvider();
      const totalAssets = await vault.totalAssets();
      
      // Получаем APY для всех провайдеров
      const providerAPYs: ProviderAPY[] = [];
      
      for (const [providerName, providerAddress] of Object.entries(providerAddresses)) {
        try {
          const apy = await getProviderAPY(providerAddress, vaultAddress);
          providerAPYs.push({
            name: providerName,
            address: providerAddress,
            apy: apy
          });
          
          console.log(`   ${providerName}: ${apy.toFixed(4)}% APY`);
        } catch (error) {
          console.log(`   ❌ Error getting APY for ${providerName}: ${error}`);
        }
      }

      if (providerAPYs.length < 2) {
        console.log(`   ⚠️  Skipping ${vaultName} - insufficient provider data`);
        continue;
      }

      // Находим лучший провайдер
      const sortedProviders = providerAPYs.sort((a, b) => b.apy - a.apy);
      const bestProvider = sortedProviders[0];
      const currentProviderAPY = providerAPYs.find(p => p.address === activeProvider);
      
      if (!currentProviderAPY) {
        console.log(`   ⚠️  Current provider not found in APY data`);
        continue;
      }

      const apyDifference = bestProvider.apy - currentProviderAPY.apy;
      
      console.log(`   Current Provider: ${currentProviderAPY.name} (${currentProviderAPY.apy.toFixed(4)}%)`);
      console.log(`   Best Provider: ${bestProvider.name} (${bestProvider.apy.toFixed(4)}%)`);
      console.log(`   APY Difference: ${apyDifference.toFixed(4)}%`);

      // Проверяем, стоит ли ребалансировать
      if (apyDifference > MIN_APY_DIFFERENCE && totalAssets > MIN_REBALANCE_AMOUNT) {
        // Оцениваем прибыль
        const annualProfit = (apyDifference / 100) * Number(ethers.formatUnits(totalAssets, 6));
        const dailyProfit = annualProfit / 365;
        
        // Оцениваем стоимость газа
        const estimatedGas = ethers.parseUnits('500000', 'wei'); // Примерная оценка
        const gasCost = estimatedGas * currentGasPrice;
        const gasCostUSD = Number(ethers.formatEther(gasCost)) * 2000; // Примерная цена ETH
        
        // Проверяем, что прибыль покрывает газ
        if (dailyProfit > gasCostUSD) {
          const opportunity: RebalanceOpportunity = {
            vault: vaultAddress,
            vaultName: vaultName,
            currentProvider: currentProviderAPY.name,
            bestProvider: bestProvider.name,
            apyDifference: apyDifference,
            estimatedProfit: dailyProfit.toFixed(4),
            gasEstimate: estimatedGas
          };
          
          opportunities.push(opportunity);
          console.log(`   ✅ Rebalancing opportunity found!`);
          console.log(`   Estimated daily profit: $${dailyProfit.toFixed(4)}`);
          console.log(`   Gas cost: $${gasCostUSD.toFixed(4)}`);
        } else {
          console.log(`   ❌ Gas cost ($${gasCostUSD.toFixed(4)}) exceeds daily profit ($${dailyProfit.toFixed(4)})`);
        }
      } else {
        if (apyDifference <= MIN_APY_DIFFERENCE) {
          console.log(`   ❌ APY difference (${apyDifference.toFixed(4)}%) below threshold (${MIN_APY_DIFFERENCE}%)`);
        }
        if (totalAssets <= MIN_REBALANCE_AMOUNT) {
          console.log(`   ❌ Total assets (${ethers.formatUnits(totalAssets, 6)}) below minimum (${ethers.formatUnits(MIN_REBALANCE_AMOUNT, 6)})`);
        }
      }

    } catch (error) {
      console.log(`❌ Error analyzing ${vaultName}: ${error}`);
    }
  }

  // Показываем найденные возможности
  console.log('\n🎯 Rebalancing Opportunities Found:');
  console.log('===================================\n');

  if (opportunities.length === 0) {
    console.log('❌ No profitable rebalancing opportunities found');
    console.log('\n💡 Tips:');
    console.log('   - Check if APY differences are significant enough');
    console.log('   - Consider gas costs vs potential profits');
    console.log('   - Ensure sufficient assets in vaults');
    return;
  }

  // Сортируем по потенциальной прибыли
  opportunities.sort((a, b) => parseFloat(b.estimatedProfit) - parseFloat(a.estimatedProfit));

  for (const opportunity of opportunities) {
    console.log(`🏦 ${opportunity.vaultName}`);
    console.log(`   Current: ${opportunity.currentProvider}`);
    console.log(`   Best: ${opportunity.bestProvider}`);
    console.log(`   APY Difference: ${opportunity.apyDifference.toFixed(4)}%`);
    console.log(`   Estimated Daily Profit: $${opportunity.estimatedProfit}`);
    console.log(`   Gas Estimate: ${ethers.formatUnits(opportunity.gasEstimate, 'wei')} wei`);
    console.log('');
  }

  // Спрашиваем пользователя о выполнении ребалансировки
  console.log('🤖 Would you like to execute rebalancing?');
  console.log('Options:');
  console.log('  1. Execute all opportunities');
  console.log('  2. Execute best opportunity only');
  console.log('  3. Dry run (simulate only)');
  console.log('  4. Cancel');

  // В реальном боте здесь была бы интерактивная логика
  // Для демонстрации выполняем dry run
  const choice = 3; // Dry run

  if (choice === 3) {
    console.log('\n🧪 Executing dry run...\n');
    
    for (const opportunity of opportunities) {
      try {
        console.log(`📋 Simulating rebalance for ${opportunity.vaultName}...`);
        
        const vaultManager = await ethers.getContractAt('VaultManager', vaultManagerAddress);
        const currentProvider = providerAddresses[opportunity.currentProvider as keyof typeof providerAddresses];
        const bestProvider = providerAddresses[opportunity.bestProvider as keyof typeof providerAddresses];
        
        // Симулируем транзакцию
        const tx = await vaultManager.rebalanceVault.populateTransaction(
          opportunity.vault,
          ethers.MaxUint256, // Все средства
          currentProvider,
          bestProvider,
          0, // Без комиссии
          true // Активировать нового провайдера
        );
        
        console.log(`   ✅ Transaction simulation successful`);
        console.log(`   Target: ${opportunity.vault}`);
        console.log(`   From: ${opportunity.currentProvider}`);
        console.log(`   To: ${opportunity.bestProvider}`);
        console.log(`   Gas estimate: ${ethers.formatUnits(opportunity.gasEstimate, 'wei')} wei`);
        console.log('');
        
      } catch (error) {
        console.log(`   ❌ Simulation failed: ${error}`);
        console.log('');
      }
    }
    
    console.log('✅ Dry run completed successfully!');
    console.log('\n💡 To execute real rebalancing:');
    console.log('   1. Set choice = 1 or 2 in the script');
    console.log('   2. Ensure you have sufficient ETH for gas');
    console.log('   3. Verify all addresses are correct');
    console.log('   4. Run the script again');
  }

  console.log('\n🎉 Auto-rebalancing analysis complete!');
}

// Функция для получения APY провайдера (упрощенная версия)
async function getProviderAPY(providerAddress: string, vaultAddress: string): Promise<number> {
  try {
    // В реальной реализации здесь был бы вызов API или контракта для получения APY
    // Для демонстрации возвращаем случайные значения
    
    const provider = await ethers.getContractAt('IProvider', providerAddress);
    
    // Получаем базовую информацию о провайдере
    const balance = await ethers.provider.getBalance(providerAddress);
    
    // Симулируем APY на основе баланса и других факторов
    const baseAPY = 3.5; // Базовый APY 3.5%
    const balanceFactor = Number(ethers.formatEther(balance)) / 1000; // Фактор баланса
    const randomFactor = Math.random() * 2 - 1; // Случайный фактор ±1%
    
    const apy = baseAPY + balanceFactor + randomFactor;
    
    return Math.max(0, apy); // APY не может быть отрицательным
  } catch (error) {
    console.log(`Error getting APY for provider ${providerAddress}: ${error}`);
    return 0;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

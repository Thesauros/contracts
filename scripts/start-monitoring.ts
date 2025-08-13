import { ethers } from 'hardhat';
import { spawn } from 'child_process';
import * as path from 'path';

interface MonitoringConfig {
  name: string;
  script: string;
  interval: number; // в секундах
  enabled: boolean;
  description: string;
}

async function main() {
  console.log('🚀 Thesauros Strategy Monitoring Dashboard');
  console.log('==========================================\n');

  // Конфигурация мониторингов
  const monitoringConfigs: MonitoringConfig[] = [
    {
      name: 'Vault Status',
      script: 'scripts/monitor-vaults.ts',
      interval: 300, // 5 минут
      enabled: true,
      description: 'Monitor TVL, APY, and vault performance'
    },
    {
      name: 'APY Analysis',
      script: 'scripts/monitor-apy.ts',
      interval: 600, // 10 минут
      enabled: true,
      description: 'Compare provider APYs and find opportunities'
    },
    {
      name: 'Event Monitor',
      script: 'scripts/monitor-events.ts',
      interval: 0, // Реальное время
      enabled: false, // Отключен по умолчанию (требует отдельного процесса)
      description: 'Real-time event monitoring'
    },
    {
      name: 'Auto-Rebalancing',
      script: 'scripts/auto-rebalance.ts',
      interval: 1800, // 30 минут
      enabled: false, // Отключен по умолчанию (требует настройки)
      description: 'Automatic rebalancing based on APY'
    }
  ];

  // Показываем доступные опции
  console.log('📋 Available Monitoring Options:');
  console.log('================================\n');

  monitoringConfigs.forEach((config, index) => {
    const status = config.enabled ? '✅' : '❌';
    const interval = config.interval > 0 ? `${config.interval}s` : 'Real-time';
    console.log(`${index + 1}. ${status} ${config.name}`);
    console.log(`   Interval: ${interval}`);
    console.log(`   Description: ${config.description}`);
    console.log('');
  });

  // Проверяем подключение к сети
  console.log('🔗 Network Connection Check:');
  console.log('============================\n');

  try {
    const network = await ethers.provider.getNetwork();
    const blockNumber = await ethers.provider.getBlockNumber();
    const gasPrice = await ethers.provider.getFeeData();
    
    console.log(`Network: ${network.name} (Chain ID: ${network.chainId})`);
    console.log(`Current Block: ${blockNumber}`);
    console.log(`Gas Price: ${ethers.formatUnits(gasPrice.gasPrice || 0, 'gwei')} gwei`);
    console.log('✅ Network connection successful\n');
  } catch (error) {
    console.log(`❌ Network connection failed: ${error}`);
    console.log('Please check your RPC configuration\n');
    return;
  }

  // Проверяем доступность контрактов
  console.log('📋 Contract Availability Check:');
  console.log('================================\n');

  const contractAddresses = {
    'VaultManager': '0xAeEcf7F780e88B155df330434Ef29b2B077024e0',
    'WETH Vault': '0x78c11f63E6840820be18fDA461Ab16f23da5884f',
    'USDC Vault': '0xdf5AFad7f88888bEE944d14982c2d9eBA65653e6',
    'USDT Vault': '0xe1D34AB80090da3498Fc5D0696a2Cf82971E5eC6',
    'DAI Vault': '0xBC64abbCa87289746f2B01C8ab02A78c9fC92B89'
  };

  for (const [name, address] of Object.entries(contractAddresses)) {
    try {
      const code = await ethers.provider.getCode(address);
      if (code !== '0x') {
        console.log(`✅ ${name}: ${address}`);
      } else {
        console.log(`❌ ${name}: Contract not found`);
      }
    } catch (error) {
      console.log(`❌ ${name}: Error checking contract`);
    }
  }

  console.log('');

  // Запускаем включенные мониторинги
  console.log('🚀 Starting Enabled Monitoring Services:');
  console.log('========================================\n');

  const activeMonitors: { [key: string]: NodeJS.Timeout } = {};

  for (const config of monitoringConfigs) {
    if (!config.enabled) {
      console.log(`⏸️  ${config.name}: Disabled`);
      continue;
    }

    if (config.interval === 0) {
      console.log(`📡 ${config.name}: Real-time monitoring (requires separate process)`);
      console.log(`   Run: npx hardhat run ${config.script} --network arbitrumOne`);
      console.log('');
      continue;
    }

    console.log(`🔄 ${config.name}: Starting with ${config.interval}s interval`);

    // Запускаем первый раз сразу
    runMonitoringScript(config.script, config.name);

    // Настраиваем повторный запуск
    const interval = setInterval(() => {
      runMonitoringScript(config.script, config.name);
    }, config.interval * 1000);

    activeMonitors[config.name] = interval;
  }

  // Показываем статистику каждые 60 секунд
  const statsInterval = setInterval(() => {
    console.log('\n📊 Monitoring Status Update:');
    console.log('============================');
    console.log(`Active monitors: ${Object.keys(activeMonitors).length}`);
    console.log(`Time: ${new Date().toLocaleString()}`);
    console.log('Press Ctrl+C to stop all monitoring');
  }, 60000);

  // Обработка завершения
  process.on('SIGINT', () => {
    console.log('\n\n🛑 Stopping all monitoring services...');
    
    // Останавливаем все интервалы
    Object.values(activeMonitors).forEach(interval => clearInterval(interval));
    clearInterval(statsInterval);
    
    console.log('✅ All monitoring services stopped');
    console.log('\n📋 Quick Commands:');
    console.log('   npx hardhat run scripts/monitor-vaults.ts --network arbitrumOne');
    console.log('   npx hardhat run scripts/monitor-apy.ts --network arbitrumOne');
    console.log('   npx hardhat run scripts/monitor-events.ts --network arbitrumOne');
    console.log('   npx hardhat run scripts/auto-rebalance.ts --network arbitrumOne');
    
    process.exit(0);
  });

  console.log('\n✅ Monitoring dashboard started successfully!');
  console.log('\n💡 Tips:');
  console.log('   - Check logs above for any errors');
  console.log('   - Monitor gas prices for optimal timing');
  console.log('   - Set up alerts for significant changes');
  console.log('   - Review APY opportunities regularly');
}

// Функция для запуска скрипта мониторинга
function runMonitoringScript(scriptPath: string, scriptName: string) {
  console.log(`\n🔄 Running ${scriptName}...`);
  console.log('─'.repeat(50));

  const child = spawn('npx', ['hardhat', 'run', scriptPath, '--network', 'arbitrumOne'], {
    stdio: 'pipe',
    shell: true
  });

  let output = '';
  let errorOutput = '';

  child.stdout?.on('data', (data) => {
    const text = data.toString();
    output += text;
    process.stdout.write(text);
  });

  child.stderr?.on('data', (data) => {
    const text = data.toString();
    errorOutput += text;
    process.stderr.write(text);
  });

  child.on('close', (code) => {
    if (code === 0) {
      console.log(`✅ ${scriptName} completed successfully`);
    } else {
      console.log(`❌ ${scriptName} failed with code ${code}`);
      if (errorOutput) {
        console.log(`Error output: ${errorOutput}`);
      }
    }
    console.log('─'.repeat(50));
  });

  child.on('error', (error) => {
    console.log(`❌ Error running ${scriptName}: ${error.message}`);
    console.log('─'.repeat(50));
  });
}

// Функция для проверки конфигурации
function validateConfig() {
  const requiredEnvVars = [
    'ARBITRUM_RPC_URL',
    'PRIVATE_KEY'
  ];

  const missing = requiredEnvVars.filter(varName => !process.env[varName]);
  
  if (missing.length > 0) {
    console.log('❌ Missing required environment variables:');
    missing.forEach(varName => console.log(`   - ${varName}`));
    console.log('\nPlease set these variables in your .env file');
    return false;
  }

  return true;
}

// Проверяем конфигурацию перед запуском
if (!validateConfig()) {
  process.exit(1);
}

main()
  .then(() => {
    // Держим процесс активным
    console.log('\n🔄 Monitoring dashboard is running...');
    console.log('Press Ctrl+C to stop');
  })
  .catch((error) => {
    console.error('❌ Error starting monitoring dashboard:', error);
    process.exit(1);
  });

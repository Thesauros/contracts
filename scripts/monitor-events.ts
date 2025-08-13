import { ethers } from 'hardhat';

interface EventLog {
  blockNumber: number;
  timestamp: number;
  transactionHash: string;
  eventName: string;
  data: any;
}

async function main() {
  console.log('📡 Thesauros Real-time Event Monitor');
  console.log('====================================\n');

  // Адреса контрактов
  const contractAddresses = {
    'VaultManager': '0xAeEcf7F780e88B155df330434Ef29b2B077024e0',
    'WETH Vault': '0x78c11f63E6840820be18fDA461Ab16f23da5884f',
    'USDC Vault': '0xdf5AFad7f88888bEE944d14982c2d9eBA65653e6',
    'USDT Vault': '0xe1D34AB80090da3498Fc5D0696a2Cf82971E5eC6',
    'DAI Vault': '0xBC64abbCa87289746f2B01C8ab02A78c9fC92B89',
    'Timelock': '0x0c5cEd804488E4AbdE6B809164e72cc0F91896b5'
  };

  const events: EventLog[] = [];
  let isMonitoring = true;

  // Функция для форматирования времени
  const formatTime = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  // Функция для форматирования адреса
  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // Функция для форматирования суммы
  const formatAmount = (amount: bigint, decimals: number = 18) => {
    return ethers.formatUnits(amount, decimals);
  };

  // Обработчик событий
  const handleEvent = async (contractName: string, eventName: string, event: any) => {
    const block = await ethers.provider.getBlock(event.blockNumber);
    const timestamp = block?.timestamp || 0;

    const eventLog: EventLog = {
      blockNumber: event.blockNumber,
      timestamp: timestamp,
      transactionHash: event.transactionHash,
      eventName: eventName,
      data: event.args
    };

    events.push(eventLog);

    console.log(`\n🔄 New Event Detected!`);
    console.log(`   Contract: ${contractName}`);
    console.log(`   Event: ${eventName}`);
    console.log(`   Block: ${event.blockNumber}`);
    console.log(`   Time: ${formatTime(timestamp)}`);
    console.log(`   TX: ${formatAddress(event.transactionHash)}`);

    // Обрабатываем специфические события
    switch (eventName) {
      case 'RebalanceExecuted':
        console.log(`   Assets From: ${formatAmount(event.args.assetsFrom)}`);
        console.log(`   Assets To: ${formatAmount(event.args.assetsTo)}`);
        console.log(`   From Provider: ${formatAddress(event.args.from)}`);
        console.log(`   To Provider: ${formatAddress(event.args.to)}`);
        break;

      case 'RebalanceVaultExecuted':
        console.log(`   Vault: ${formatAddress(event.args.vault)}`);
        console.log(`   Assets: ${formatAmount(event.args.assets)}`);
        console.log(`   Success: ${event.args.success}`);
        break;

      case 'FeeCharged':
        console.log(`   Treasury: ${formatAddress(event.args.treasury)}`);
        console.log(`   Assets: ${formatAmount(event.args.assets)}`);
        console.log(`   Fee: ${formatAmount(event.args.fee)}`);
        break;

      case 'ActiveProviderUpdated':
        console.log(`   New Provider: ${formatAddress(event.args.activeProvider)}`);
        break;

      case 'Queued':
        console.log(`   Target: ${formatAddress(event.args.target)}`);
        console.log(`   Value: ${event.args.value}`);
        console.log(`   Signature: ${event.args.signature}`);
        console.log(`   Timestamp: ${formatTime(event.args.timestamp)}`);
        break;

      case 'Executed':
        console.log(`   Target: ${formatAddress(event.args.target)}`);
        console.log(`   Value: ${event.args.value}`);
        console.log(`   Signature: ${event.args.signature}`);
        break;

      default:
        console.log(`   Data: ${JSON.stringify(event.args, null, 2)}`);
    }

    console.log('   ' + '─'.repeat(50));
  };

  // Настраиваем слушатели событий
  console.log('🔧 Setting up event listeners...\n');

  try {
    // VaultManager события
    const vaultManager = await ethers.getContractAt('VaultManager', contractAddresses.VaultManager);
    
    vaultManager.on('RebalanceVaultExecuted', (vault, assets, from, to, fee, activateToProvider, success) => {
      handleEvent('VaultManager', 'RebalanceVaultExecuted', {
        blockNumber: 0, // Будет заполнено в handleEvent
        transactionHash: '', // Будет заполнено в handleEvent
        args: { vault, assets, from, to, fee, activateToProvider, success }
      });
    });

    // Vault события
    for (const [vaultName, vaultAddress] of Object.entries(contractAddresses)) {
      if (vaultName.includes('Vault')) {
        const vault = await ethers.getContractAt('Rebalancer', vaultAddress);
        
        vault.on('RebalanceExecuted', (assetsFrom, assetsTo, from, to) => {
          handleEvent(vaultName, 'RebalanceExecuted', {
            blockNumber: 0,
            transactionHash: '',
            args: { assetsFrom, assetsTo, from, to }
          });
        });

        vault.on('FeeCharged', (treasury, assets, fee) => {
          handleEvent(vaultName, 'FeeCharged', {
            blockNumber: 0,
            transactionHash: '',
            args: { treasury, assets, fee }
          });
        });

        vault.on('ActiveProviderUpdated', (activeProvider) => {
          handleEvent(vaultName, 'ActiveProviderUpdated', {
            blockNumber: 0,
            transactionHash: '',
            args: { activeProvider }
          });
        });

        vault.on('Deposit', (caller, owner, assets, shares) => {
          handleEvent(vaultName, 'Deposit', {
            blockNumber: 0,
            transactionHash: '',
            args: { caller, owner, assets, shares }
          });
        });

        vault.on('Withdraw', (caller, receiver, owner, assets, shares) => {
          handleEvent(vaultName, 'Withdraw', {
            blockNumber: 0,
            transactionHash: '',
            args: { caller, receiver, owner, assets, shares }
          });
        });
      }
    }

    // Timelock события
    const timelock = await ethers.getContractAt('Timelock', contractAddresses.Timelock);
    
    timelock.on('Queued', (txId, target, value, signature, data, timestamp) => {
      handleEvent('Timelock', 'Queued', {
        blockNumber: 0,
        transactionHash: '',
        args: { txId, target, value, signature, data, timestamp }
      });
    });

    timelock.on('Executed', (txId, target, value, signature, data, timestamp) => {
      handleEvent('Timelock', 'Executed', {
        blockNumber: 0,
        transactionHash: '',
        args: { txId, target, value, signature, data, timestamp }
      });
    });

    timelock.on('Cancelled', (txId, target, value, signature, data, timestamp) => {
      handleEvent('Timelock', 'Cancelled', {
        blockNumber: 0,
        transactionHash: '',
        args: { txId, target, value, signature, data, timestamp }
      });
    });

  } catch (error) {
    console.log(`❌ Error setting up event listeners: ${error}`);
    return;
  }

  console.log('✅ Event listeners configured successfully!');
  console.log('📡 Monitoring started. Press Ctrl+C to stop.\n');

  // Показываем статистику каждые 30 секунд
  const statsInterval = setInterval(() => {
    if (!isMonitoring) {
      clearInterval(statsInterval);
      return;
    }

    const now = Math.floor(Date.now() / 1000);
    const recentEvents = events.filter(e => now - e.timestamp < 300); // Последние 5 минут

    console.log(`\n📊 Monitoring Stats (Last 5 minutes):`);
    console.log(`   Total events: ${recentEvents.length}`);
    console.log(`   Rebalancing events: ${recentEvents.filter(e => e.eventName.includes('Rebalance')).length}`);
    console.log(`   Deposit events: ${recentEvents.filter(e => e.eventName === 'Deposit').length}`);
    console.log(`   Withdraw events: ${recentEvents.filter(e => e.eventName === 'Withdraw').length}`);
    console.log(`   Timelock events: ${recentEvents.filter(e => e.eventName === 'Queued' || e.eventName === 'Executed').length}`);
  }, 30000);

  // Обработка завершения
  process.on('SIGINT', () => {
    console.log('\n\n🛑 Stopping event monitor...');
    isMonitoring = false;
    clearInterval(statsInterval);
    
    // Отключаем все слушатели
    ethers.provider.removeAllListeners();
    
    console.log('📋 Event Summary:');
    console.log(`   Total events captured: ${events.length}`);
    
    if (events.length > 0) {
      console.log('\n📅 Recent Events:');
      const recentEvents = events.slice(-10); // Последние 10 событий
      
      for (const event of recentEvents) {
        console.log(`   ${formatTime(event.timestamp)} - ${event.eventName} (Block ${event.blockNumber})`);
      }
    }
    
    console.log('✅ Monitoring stopped.');
    process.exit(0);
  });

  // Обработка ошибок
  process.on('unhandledRejection', (error) => {
    console.log(`❌ Unhandled error: ${error}`);
  });

  // Держим процесс активным
  await new Promise(() => {});
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

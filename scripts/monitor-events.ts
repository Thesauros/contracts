import { ethers } from 'hardhat';
import { ConfigLoader } from '../utils/config';

interface EventLog {
  blockNumber: number;
  timestamp: number;
  transactionHash: string;
  eventName: string;
  data: any;
}

async function main() {
  console.log('Thesauros Real-time Event Monitor');
  console.log('====================================\n');

  // Load configuration
  const configLoader = new ConfigLoader();
  const config = configLoader.loadConfig();
  
  if (!config) {
    console.error('Failed to load configuration');
    return;
  }

  // Contract addresses from config
  const contractAddresses = {
    'VaultManager': config.baseContracts.VaultManager.address,
    'Timelock': config.baseContracts.Timelock.address,
    ...Object.fromEntries(
      Object.entries(config.vaults).map(([token, vault]) => [
        `${token} Vault`, 
        vault.address
      ])
    )
  };

  const events: EventLog[] = [];
  let isMonitoring = true;

  // Function to format time
  const formatTime = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  // Function to format address
  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // Function to format amount
  const formatAmount = (amount: bigint, decimals: number = 18) => {
    return ethers.formatUnits(amount, decimals);
  };

  // Event handler
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

    console.log(`\nNew Event Detected!`);
    console.log(`   Contract: ${contractName}`);
    console.log(`   Event: ${eventName}`);
    console.log(`   Block: ${event.blockNumber}`);
    console.log(`   Time: ${formatTime(timestamp)}`);
    console.log(`   TX: ${formatAddress(event.transactionHash)}`);

    // Handle specific events
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
        console.log(`   Timestamp: ${formatTime(event.args.timestamp)}`);
        break;

      case 'Deposit':
        console.log(`   Sender: ${formatAddress(event.args.sender)}`);
        console.log(`   Owner: ${formatAddress(event.args.owner)}`);
        console.log(`   Assets: ${formatAmount(event.args.assets)}`);
        console.log(`   Shares: ${formatAmount(event.args.shares)}`);
        break;

      case 'Withdraw':
        console.log(`   Sender: ${formatAddress(event.args.sender)}`);
        console.log(`   Receiver: ${formatAddress(event.args.receiver)}`);
        console.log(`   Owner: ${formatAddress(event.args.owner)}`);
        console.log(`   Assets: ${formatAmount(event.args.assets)}`);
        console.log(`   Shares: ${formatAmount(event.args.shares)}`);
        break;

      default:
        console.log(`   Data: ${JSON.stringify(event.args, null, 2)}`);
    }

    console.log('   ' + '='.repeat(50));
  };

  // Setup event listeners for each contract
  const contracts = new Map();

  for (const [name, address] of Object.entries(contractAddresses)) {
    try {
      console.log(`Setting up monitoring for ${name} at ${formatAddress(address)}`);
      
      const contract = new ethers.Contract(address, [
        'event RebalanceExecuted(address indexed from, address indexed to, uint256 assetsFrom, uint256 assetsTo)',
        'event RebalanceVaultExecuted(address indexed vault, uint256 assets, bool success)',
        'event FeeCharged(address indexed treasury, uint256 assets, uint256 fee)',
        'event ActiveProviderUpdated(address indexed activeProvider)',
        'event Queued(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 timestamp)',
        'event Executed(bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 timestamp)',
        'event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares)',
        'event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)'
      ], ethers.provider);

      contracts.set(name, contract);

      // Listen for all events
      contract.on('*', (event) => {
        handleEvent(name, event.eventName, event);
      });

    } catch (error) {
      console.error(`Error setting up monitoring for ${name}:`, error);
    }
  }

  console.log('\nMonitoring started. Press Ctrl+C to stop.\n');

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\nStopping event monitoring...');
    isMonitoring = false;
    
    // Remove all listeners
    for (const [name, contract] of contracts) {
      contract.removeAllListeners();
    }
    
    console.log('Event monitoring stopped.');
    process.exit(0);
  });

  // Keep the process alive
  while (isMonitoring) {
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}

main().catch((error) => {
  console.error('Error in event monitoring:', error);
  process.exit(1);
});

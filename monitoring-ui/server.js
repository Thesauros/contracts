const express = require('express');
const cors = require('cors');
const path = require('path');
const { ethers } = require('ethers');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname)));

// Initialize provider with retry logic
let provider;
async function initializeProvider() {
  try {
    provider = new ethers.JsonRpcProvider(process.env.ARBITRUM_ONE_RPC_URL || 'https://arb1.arbitrum.io/rpc');
    await provider.getNetwork(); // Test connection
    console.log('Provider initialized successfully');
  } catch (error) {
    console.error('Failed to initialize provider:', error);
    process.exit(1);
  }
}

// Load configuration
const configPath = path.join(__dirname, '..', 'deployments', 'arbitrumOne', 'deployed-vaults.json');
let config = null;

try {
  config = require(configPath);
  console.log('Configuration loaded successfully');
} catch (error) {
  console.error('Failed to load config:', error);
}

// Helper function to serialize BigInt values
function serializeData(data) {
  return JSON.parse(JSON.stringify(data, (key, value) => {
    if (typeof value === 'bigint') {
      return value.toString();
    }
    return value;
  }));
}

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

app.get('/api/vaults', async (req, res) => {
  try {
    const vaults = await getVaultData();
    res.json(serializeData(vaults));
  } catch (error) {
    console.error('Error fetching vaults:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/providers', async (req, res) => {
  try {
    const providers = await getProviderData();
    res.json(serializeData(providers));
  } catch (error) {
    console.error('Error fetching providers:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/apy', async (req, res) => {
  try {
    const apyData = await getAPYData();
    res.json(serializeData(apyData));
  } catch (error) {
    console.error('Error fetching APY data:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/events', async (req, res) => {
  try {
    const events = await getRecentEvents();
    res.json(serializeData(events));
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/dashboard', async (req, res) => {
  try {
    const dashboardData = {
      vaults: await getVaultData(),
      providers: await getProviderData(),
      apyData: await getAPYData(),
      events: await getRecentEvents(),
      networkInfo: await getNetworkInfo(),
      lastUpdate: new Date().toISOString()
    };
    
    res.json(serializeData(dashboardData));
  } catch (error) {
    console.error('Error fetching dashboard data:', error);
    res.status(500).json({ error: error.message });
  }
});

// Data fetching functions
async function getVaultData() {
  if (!config) return [];
  
  const vaults = [];
  
  for (const [token, vaultConfig] of Object.entries(config.vaults)) {
    try {
      const vault = new ethers.Contract(vaultConfig.address, [
        'function totalAssets() view returns (uint256)',
        'function totalSupply() view returns (uint256)',
        'function asset() view returns (address)',
        'function activeProvider() view returns (address)'
      ], provider);
      
      const [totalAssets, totalShares, asset, activeProvider] = await Promise.all([
        vault.totalAssets(),
        vault.totalSupply(),
        vault.asset(),
        vault.activeProvider()
      ]);
      
      const decimals = getTokenDecimals(token);
      const tvl = ethers.formatUnits(totalAssets, decimals);
      const shares = ethers.formatUnits(totalShares, 18);
      
      vaults.push({
        name: vaultConfig.name,
        symbol: vaultConfig.symbol,
        address: vaultConfig.address,
        asset: asset,
        tvl: tvl,
        totalShares: shares,
        activeProvider: activeProvider,
        token: token,
        status: vaultConfig.status
      });
    } catch (error) {
      console.error(`Error fetching vault data for ${token}:`, error);
      vaults.push({
        name: vaultConfig.name,
        symbol: vaultConfig.symbol,
        address: vaultConfig.address,
        error: error.message,
        token: token,
        status: 'error'
      });
    }
  }
  
  return vaults;
}

async function getProviderData() {
  if (!config) return [];
  
  const providers = [];
  
  for (const [name, contractConfig] of Object.entries(config.baseContracts)) {
    if (name.includes('Provider')) {
      try {
        const balance = await provider.getBalance(contractConfig.address);
        
        providers.push({
          name: name,
          address: contractConfig.address,
          balance: ethers.formatEther(balance),
          status: contractConfig.status
        });
      } catch (error) {
        console.error(`Error fetching provider data for ${name}:`, error);
        providers.push({
          name: name,
          address: contractConfig.address,
          error: error.message,
          status: 'error'
        });
      }
    }
  }
  
  return providers;
}

async function getAPYData() {
  const apyData = [];
  
  if (config) {
    for (const [token, address] of Object.entries(config.tokenAddresses)) {
      const baseAPY = 3.5;
      const randomFactor = Math.random() * 2 - 1;
      const apy = Math.max(0, baseAPY + randomFactor);
      
      apyData.push({
        token: token,
        address: address,
        apy: apy.toFixed(4),
        source: 'simulated'
      });
    }
  }
  
  return apyData;
}

async function getRecentEvents() {
  return [
    {
      type: 'RebalanceExecuted',
      vault: 'WETH Vault',
      timestamp: new Date(Date.now() - 3600000).toISOString(),
      txHash: '0x1234...5678',
      success: true
    }
  ];
}

async function getNetworkInfo() {
  try {
    const [blockNumber, gasPrice] = await Promise.all([
      provider.getBlockNumber(),
      provider.getFeeData()
    ]);
    
    return {
      chainId: await provider.getNetwork().then(n => n.chainId),
      blockNumber: blockNumber,
      gasPrice: ethers.formatUnits(gasPrice.gasPrice, 'gwei'),
      lastUpdate: new Date().toISOString()
    };
  } catch (error) {
    return {
      error: error.message,
      lastUpdate: new Date().toISOString()
    };
  }
}

function getTokenDecimals(token) {
  const decimals = {
    'WETH': 18,
    'USDC': 6,
    'USDT': 6,
    'DAI': 18,
    'FRAX': 18,
    'USDC_e': 6
  };
  return decimals[token] || 18;
}

// Serve simple HTML dashboard
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'simple-dashboard.html'));
});

// Serve simple HTML dashboard for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'simple-dashboard.html'));
});

app.listen(PORT, () => {
  console.log(`Monitoring UI server running on port ${PORT}`);
  console.log(`Dashboard available at http://localhost:${PORT}`);
});

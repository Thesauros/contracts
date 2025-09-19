import { ethers } from 'hardhat';
// ARBITRUM ONE TOKEN ADDRESSES
export const tokenAddresses = {
  WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  USDT: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
  USDC: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
  USDC_e: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8',
};

export const cometTokens = {
  cWETH: '0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486',
  cUSDT: '0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07',
  cUSDC: '0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf',
  cUSDC_e: '0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA',
};

export const cometPairs = [
  {
    asset: tokenAddresses.WETH,
    cToken: cometTokens.cWETH,
  },
  {
    asset: tokenAddresses.USDT,
    cToken: cometTokens.cUSDT,
  },
  {
    asset: tokenAddresses.USDC,
    cToken: cometTokens.cUSDC,
  },
  {
    asset: tokenAddresses.USDC_e,
    cToken: cometTokens.cUSDC_e,
  },
];

// Ethena Protocol addresses for Arbitrum network
// Note: Ethena Protocol is planning to deploy on Arbitrum via Converge blockchain
// These addresses will be updated when Ethena Protocol is deployed on Arbitrum
// For now, we use mock contracts for testing
export const ethenaAddresses = {
  USDe: '0x4c9edd5852cd905f086c759e8383e09bff1e68b3', // Will be set after mock deployment
  staking: '0x0000000000000000000000000000000000000000', // Will be set after mock deployment
};

export const ethenaPairs = [
  {
    asset: tokenAddresses.USDT,
    usdeToken: ethenaAddresses.USDe,
    stakingContract: ethenaAddresses.staking,
  },
  {
    asset: tokenAddresses.USDC,
    usdeToken: ethenaAddresses.USDe,
    stakingContract: ethenaAddresses.staking,
  },
];

// export const vaults = [];

export const ARBITRUM_CHAIN_ID = 42161n;
export const ARBITRUM_SEPOLIA_CHAIN_ID = 421614n;

export const TREASURY_ADDRESS = '0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D';

export const ADMIN_ROLE = '0x50662aEDe1e73a1f6ffc6b3bBB1EA5C4D8083eD5';
export const OPERATOR_ROLE = ethers.id('OPERATOR_ROLE');
export const EXECUTOR_ROLE = ethers.id('EXECUTOR_ROLE');

export const WITHDRAW_FEE_PERCENT = ethers.parseEther('0.001'); // 0.1%

import { ethers } from 'hardhat';

export const tokenAddresses = {
  WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  USDT: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
  USDC: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
  DAI: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
  FRAX: '0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F',
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

// export const vaults = [];

export const ARBITRUM_CHAIN_ID = 42161n;
export const ARBITRUM_SEPOLIA_CHAIN_ID = 421614n;

export const TREASURY_ADDRESS = '0xc8a682F0991323777253ffa5fa6F19035685E723';

export const ADMIN_ROLE = ethers.ZeroHash;
export const OPERATOR_ROLE = ethers.id('OPERATOR_ROLE');
export const EXECUTOR_ROLE = ethers.id('EXECUTOR_ROLE');

export const WITHDRAW_FEE_PERCENT = ethers.parseEther('0.001'); // 0.1%

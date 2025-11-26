import { ethers } from 'hardhat';

export const tokenAddresses = {
  USDC: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
};

export const cometTokens = {
  cUSDC: '0xb125E6687d4313864e53df431d5425969c15Eb2F',
};

export const cometPairs = [
  {
    asset: tokenAddresses.USDC,
    cToken: cometTokens.cUSDC,
  },
];

export const morphoVaults = [
  {
    strategy: 'Re7',
    vaultAddress: '0x12AFDeFb2237a5963e7BAb3e2D46ad0eee70406e',
  },
  {
    strategy: 'Steakhouse High Yield',
    vaultAddress: '0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F',
  },
  {
    strategy: 'Steakhouse Prime',
    vaultAddress: '0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2',
  },
  {
    strategy: 'Gauntlet Core',
    vaultAddress: '0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12',
  },
];

export const BASE_CHAIN_ID = 8453n;

export const TREASURY_ADDRESS = '0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D';

export const ADMIN_ROLE = ethers.ZeroHash;
export const OPERATOR_ROLE = ethers.id('OPERATOR_ROLE');
export const EXECUTOR_ROLE = ethers.id('EXECUTOR_ROLE');

export const WITHDRAW_FEE_PERCENT = ethers.parseEther('0.001'); // 0.1%

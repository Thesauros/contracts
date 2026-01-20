import { ethers } from 'hardhat';

export const tokenAddresses = {
  USDC: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  USDT: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
};

export const cometTokens = {
  cUSDC: '0xc3d688B66703497DAA19211EEdff47f25384cdc3',
  cUSDT: '0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840',
};

export const cometPairs = [
  {
    asset: tokenAddresses.USDC,
    cToken: cometTokens.cUSDC,
  },
  {
    asset: tokenAddresses.USDT,
    cToken: cometTokens.cUSDT,
  },
];

export const morphoVaults = [
  {
    strategy: 'Steakhouse',
    vaultAddress: '0xBEEF01735c132Ada46AA9aA4c54623cAA92A64CB',
  },
  {
    strategy: 'OEVBoosted',
    vaultAddress: '0x68Aea7b82Df6CcdF76235D46445Ed83f85F845A3',
  },
  {
    strategy: 'GauntletPrime',
    vaultAddress: '0xdd0f28e19C1780eb6396170735D45153D261490d',
  },
  {
    strategy: 'GauntletRWA',
    vaultAddress: '0xA8875aaeBc4f830524e35d57F9772FfAcbdD6C45',
  },
  {
    strategy: 'GauntletFrontier',
    vaultAddress: '0xc582F04d8a82795aa2Ff9c8bb4c1c889fe7b754e',
  },
  {
    strategy: 'GauntletCore',
    vaultAddress: '0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458',
  },
  {
    strategy: 'ClearstarHighYield',
    vaultAddress: '0x9B5E92fd227876b4C07a8c02367E2CB23c639DfA',
  },
];

export const ETHEREUM_CHAIN_ID = 1n;

export const TREASURY_ADDRESS = process.env.TREASURY_ADDRESS;
export const WITHDRAW_FEE_PERCENT = BigInt(
  process.env.WITHDRAW_FEE_PERCENT || '0',
);
export const TIMELOCK_DELAY = Number(process.env.TIMELOCK_DELAY || '1800');

export const ADMIN_ROLE = ethers.ZeroHash;
export const OPERATOR_ROLE = ethers.id('OPERATOR_ROLE');
export const EXECUTOR_ROLE = ethers.id('EXECUTOR_ROLE');

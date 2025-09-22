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
    strategy: 'Spark',
    vaultAddress: '0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A',
  },
  {
    strategy: 'Moonwell',
    vaultAddress: '0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca',
  },
  {
    strategy: 'Seamless',
    vaultAddress: '0x616a4E1db48e22028f6bbf20444Cd3b8e3273738',
  },
  {
    strategy: 'Steakhouse',
    vaultAddress: '0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183',
  },
  {
    strategy: 'Gauntlet Prime',
    vaultAddress: '0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61',
  },
  {
    strategy: 'Gauntlet Core',
    vaultAddress: '0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12',
  },
  {
    strategy: 'Apostro Resolv',
    vaultAddress: '0xcdDCDd18A16ED441F6CB10c3909e5e7ec2B9e8f3',
  },
];

export const BASE_CHAIN_ID = 8453n;

export const TREASURY_ADDRESS = '0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D';

export const ADMIN_ROLE = ethers.ZeroHash;
export const OPERATOR_ROLE = ethers.id('OPERATOR_ROLE');
export const EXECUTOR_ROLE = ethers.id('EXECUTOR_ROLE');

export const WITHDRAW_FEE_PERCENT = ethers.parseEther('0.001'); // 0.1%

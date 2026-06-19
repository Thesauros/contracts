import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-foundry';
import 'hardhat-deploy';
import 'dotenv/config';

import { networkConfig } from './network-config';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.23',
    settings: { optimizer: { enabled: true, runs: 1 } },
  },
  mocha: {
    timeout: 150000000,
  },
  networks: networkConfig,
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ETHERSCAN_API_KEY!,
      // Ink explorer is Blockscout: any non-empty string works as the key
      ink: process.env.INK_EXPLORER_API_KEY || 'blockscout',
    },
    customChains: [
      {
        network: 'ink',
        chainId: 57073,
        urls: {
          apiURL: 'https://explorer.inkonchain.com/api',
          browserURL: 'https://explorer.inkonchain.com',
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
};

export default config;

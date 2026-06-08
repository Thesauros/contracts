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
      // Plasmascan is powered by Routescan: any non-empty string works as the key
      plasma: process.env.PLASMASCAN_API_KEY || 'plasmascan',
    },
    customChains: [
      {
        network: 'plasma',
        chainId: 9745,
        urls: {
          apiURL:
            'https://api.routescan.io/v2/network/mainnet/evm/9745/etherscan',
          browserURL: 'https://plasmascan.to',
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
};

export default config;

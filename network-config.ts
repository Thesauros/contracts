export const networkUrls = {
  arbitrumOne: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`,
  arbitrumSepolia: `https://arbitrum-sepolia.blockpi.network/v1/rpc/public`,
  plasma: process.env.PLASMA_RPC_URL || `https://rpc.plasma.to`,
};

export const networkConfig = {
  localhost: {
    chainId: 31337,
  },
  hardhat: {
    forking: {
      url: process.env.ARBITRUM_RPC_URL || networkUrls.arbitrumOne,
    },
  },
  arbitrumOne: {
    url: networkUrls.arbitrumOne,
    accounts: process.env.DEPLOYER_PRIVATE_KEY
      ? [process.env.DEPLOYER_PRIVATE_KEY]
      : [],
    chainId: 42161,
    gasPrice: 120000000, // 0.12 Gwei
  },
  arbitrumSepolia: {
    url: networkUrls.arbitrumSepolia,
    accounts: process.env.DEPLOYER_PRIVATE_KEY
      ? [process.env.DEPLOYER_PRIVATE_KEY]
      : [],
    chainId: 421614,
  },
  plasma: {
    url: networkUrls.plasma,
    accounts: process.env.DEPLOYER_PRIVATE_KEY
      ? [process.env.DEPLOYER_PRIVATE_KEY]
      : [],
    chainId: 9745,
  },
};

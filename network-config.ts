export const networkUrls = {
  arbitrumOne: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`,
  arbitrumSepolia: `https://arbitrum-sepolia.blockpi.network/v1/rpc/public`,
  base: `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`,
};

export const networkConfig = {
  localhost: {
    chainId: 31337,
  },
  hardhat: {
    forking: {
      url: networkUrls.arbitrumOne,
      blockNumber: 233407190,
    },
  },
  arbitrumOne: {
    url: networkUrls.arbitrumOne,
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    chainId: 42161,
    gasPrice: 100000000,
  },
  arbitrumSepolia: {
    url: networkUrls.arbitrumSepolia,
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    chainId: 421614,
  },
  base: {
    url: networkUrls.base,
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    chainId: 8453,
    gasPrice: 1000000000, // 1 gwei
  },
};

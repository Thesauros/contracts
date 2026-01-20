export const networkUrls = {
  ethereum: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`,
  ethereumSepolia: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`
};

export const networkConfig = {
  localhost: {
    chainId: 31337,
  },
  hardhat: {
    forking: {
      url: networkUrls.ethereum,
    },
  },
  ethereum: {
    url: networkUrls.ethereum,
    accounts: process.env.DEPLOYER_PRIVATE_KEY
      ? [process.env.DEPLOYER_PRIVATE_KEY]
      : [],
    chainId: 1,
    gasPrice: 80000000, // 0.08 Gwei
  },
  ethereumSepolia: {
    url: networkUrls.ethereumSepolia,
    accounts: process.env.DEPLOYER_PRIVATE_KEY
      ? [process.env.DEPLOYER_PRIVATE_KEY]
      : [],
    chainId: 11155111,
  },
};

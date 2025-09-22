export const BASE_URL = `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_PROJECT_ID}`;

export const networkConfig = {
  localhost: {
    chainId: 31337,
  },
  base: {
    url: BASE_URL,
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    chainId: 8453,
    gasPrice: 4000000,
  },
};

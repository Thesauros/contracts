export const BASE_URL = process.env.BASE_RPC_URL || 'https://mainnet.base.org';

export const networkConfig = {
  localhost: {
    chainId: 31337,
  },
  base: {
    url: BASE_URL,
    accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    chainId: 8453,
    gasPrice: 8000000, // Further increased gas price
  },
};

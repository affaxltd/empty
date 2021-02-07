const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

const env = process.env;

module.exports = {
  networks: {
    fork: {
      host: "127.0.0.1",
      port: 8545,
      gas: 7500000,
      gasPrice: 45000000000,
      network_id: 1,
    },
    kovan: {
      provider: () => new HDWalletProvider(env.MEMO, env.KINFURA),
      gas: 7500000,
      gasPrice: 4500000000,
      network_id: 42,
    },
    mainnet: {
      provider: () => new HDWalletProvider(env.MEMO, env.INFURA),
      gas: 7500000,
      gasPrice: 45000000000,
      network_id: 1,
    },
  },
  compilers: {
    solc: {
      version: "0.7.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  plugins: ["truffle-plugin-verify"],
  api_keys: {
    etherscan: env.ETHERSCAN_API,
  },
};

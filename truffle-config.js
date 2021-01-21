const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();

const env = process.env;

module.exports = {
  networks: {
    fork: {
      host: "127.0.0.1",
      port: 8545,
      gas: 15000000,
      gasPrice: 21000000000,
      network_id: 1,
    },
    kovan: {
      provider: () => new HDWalletProvider(env.MEMO, env.INFURA),
      gas: 5000000,
      gasPrice: 30000000000,
      network_id: 42,
    },
    mainnet: {
      provider: () => new HDWalletProvider(env.MEMO, env.INFURA),
      gas: 5000000,
      gasPrice: 11000000000,
      network_id: 1,
    },
  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};

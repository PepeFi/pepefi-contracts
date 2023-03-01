require("@nomiclabs/hardhat-waffle");
require('hardhat-abi-exporter');
require("hardhat-interface-generator");
require('hardhat-contract-sizer');
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");

require('dotenv').config()
/**
 * @type import('hardhat/config').HardhatUserConfig
 */

abiExporter: [
  {
    pretty: false,
    runOnCompile: true
  }
]


module.exports = {
  defaultNetwork: 'hardhat',
  solidity: "0.8.9",
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    }
  },
  networks: {
    hardhat: {
      chainId: 1337,
      forking: {
        url: `https://eth-goerli.alchemyapi.io/v2/${process.env.ALCHEMY_API}`,
        accounts: [process.env.ETH_KEY]
      }
    },
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${process.env.ALCHEMY_API}`,
      accounts: [process.env.ETH_KEY]
    },
  },
  gasReporter: {
    currency: 'USD'
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API
  },
  gasPrice: 0
};

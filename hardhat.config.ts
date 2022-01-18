import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-web3";
import "hardhat-gas-reporter"

require('dotenv').config()
require("hardhat-gas-reporter");

export default {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    currency: 'USD',
    gasPrice: 21
  }
}
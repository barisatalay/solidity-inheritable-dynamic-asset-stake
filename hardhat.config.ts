import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-web3";

require('dotenv').config()


export default {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
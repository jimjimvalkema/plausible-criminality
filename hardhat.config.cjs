require("@nomicfoundation/hardhat-toolbox");
const ETHERSCAN_KEY = vars.get("ETHERSCAN_KEY");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/2LPfLOYBTHSHfLWYSv8xib2Y7OA",
      accounts: [PRIVATE_KEY],
      chainId: 11155111,
      ethNetwork: "sepolia",
    },
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_KEY,
    },
  }
};

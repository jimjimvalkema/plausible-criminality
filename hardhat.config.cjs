require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
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
    inksepolia: {
      url: "https://rpc-gel-sepolia.inkonchain.com/",
      chainId: 763373,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_KEY,
      inkSepolia: "a153d491-ac53-41d6-b57b-5b519d8c6def",
    },
  },
  customChains: [
    {
      network: "inksepolia",
      chainId: 763373,
      urls: {
        apiURL: "https://explorer-sepolia.inkonchain.com/api",
        browserURL: "https://explorer-sepolia.inkonchain.com/",
      },
    },
  ],
  sourcify: {
    enabled: false
  }
};

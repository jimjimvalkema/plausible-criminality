import { ethers } from "ethers";
import UltraAnonDeploymentArtifact from "../artifacts/contracts/UltraAnon.sol/UltraAnon.json"
import {syncInComingBalanceTree, syncShadowTree} from "../scripts/syncMaxing.js"
window.syncInComingBalanceTree = syncInComingBalanceTree
window.syncShadowTree = syncShadowTree

const ultraAnonAbi = UltraAnonDeploymentArtifact.abi
const ultraAnonAddress = "0x46AeaE909299b8cA4a5B77De45f7Ac540a25a0F8"//UltraAnonDeploymentArtifact.
const deploymentBlock = 7791355;
const CHAININFO = {
    chainId: "0xaa36a7",
    rpcUrls: ["https://1rpc.io/sepolia"],
    chainName: "Sepolia",
    nativeCurrency: {
      name: "ethereum",
      symbol: "ETH",
      decimals: 18
    },
    blockExplorerUrls: ["https://sepolia.etherscan.io/"]
  }


  async function switchNetwork(network, provider) {
    try {
      await provider.send("wallet_switchEthereumChain", [{ chainId: network.chainId }]);
  
    } catch (switchError) {
      window.switchError = switchError
      // This error code indicates that the chain has not been added to MetaMask.
      if (switchError.error && switchError.error.code === 4902) {
        try {
          await provider.send("wallet_addEthereumChain", [network]);
  
        } catch (addError) {
          // handle "add" error
        }
      }
      // handle other "switch" errors
    }
  }
async function main() {

    const provider = new ethers.BrowserProvider(window.ethereum)
    await switchNetwork(CHAININFO,provider)
    const signer = await provider.getSigner();
    const ultraAnonContract = new ethers.Contract(ultraAnonAddress, ultraAnonAbi, signer)
    
    //debug shite
    window.ethers = ethers
    window.ultraAnonContract = ultraAnonContract
    window.provider = provider
    window.signer = signer

}

await main()

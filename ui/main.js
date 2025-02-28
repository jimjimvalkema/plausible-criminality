// node_modules
import { ethers } from "ethers";
import { poseidon1, poseidon2 } from "poseidon-lite";

// abis, circuits
import UltraAnonDeploymentArtifact from "../artifacts/contracts/UltraAnon.sol/UltraAnon.json" with { type: "json" }
import privateTransactionCircuit from '../circuits/privateTransfer/target/privateTransfer.json'  with { type: "json" }; //assert {type: 'json'};
import publicTransactionCircuit from '../circuits/publicTransfer/target/publicTransfer.json'  with { type: "json" }; //assert {type: 'json'};

// local imports
import { syncInComingBalanceTree as syncIncomingBalanceTree, syncShadowTree, syncShadowBalance } from "../scripts/syncMaxing.js"
import { hashAddress, hashNullifierKey, hashNullifierValue, hashShadowBalanceTreeLeaf, hashIncomingBalanceTreeLeaf } from "../scripts/hashor.js"
import { makeNoirTest } from "../scripts/makeNoirTest.js"
import {privateTransfer, publicTransfer} from "../scripts/transactionBuilder.js"

import {setEventHandlers} from "./eventHandlers.js"

// noir
import { Noir } from "@noir-lang/noir_js";
import { UltraPlonkBackend } from '@aztec/bb.js';


const ultraAnonAbi = UltraAnonDeploymentArtifact.abi
const ultraAnonAddress = "0xE60b3a62fFF29f04f643B538BF63145F281c769c"
const deploymentBlock = 7793115;

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
    await switchNetwork(CHAININFO, provider)
    const signer = await provider.getSigner();
    const ultraAnonContract = new ethers.Contract(ultraAnonAddress, ultraAnonAbi, signer)
    setEventHandlers({ultraAnonContract, deploymentBlock: deploymentBlock})

    //debug shite
    window.ethers = ethers
    window.ultraAnonContract = ultraAnonContract
    window.provider = provider
    window.signer = signer
    window.poseidon1 = poseidon1
    window.poseidon2 = poseidon2
    window.syncInComingBalanceTree = syncIncomingBalanceTree
    window.syncShadowTree = syncShadowTree
    window.syncShadowBalance = syncShadowBalance
    window.hashAddress = hashAddress
    window.hashNullifierKey =hashNullifierKey
    window.privateTransfer= privateTransfer
    window.publicTransfer = publicTransfer
    window.deploymentBlock = deploymentBlock
}

await main()


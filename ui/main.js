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
const ultraAnonAddress = "0x6650F12e7e71F8F29454596B8E54014EA2c68286"
const deploymentBlock = 7808380;

const CHAININFO = {
    chainId: "0x0ba5ed",
    rpcUrls: ["https://rpc-gel-sepolia.inkonchain.com/"],
    chainName: "Sepolia",
    nativeCurrency: {
        name: "ethereum",
        symbol: "ETH",
        decimals: 18
    },
    blockExplorerUrls: ["https://explorer-sepolia.inkonchain.com//"]
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


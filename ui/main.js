
import { ethers } from "ethers";
import UltraAnonDeploymentArtifact from "../artifacts/contracts/UltraAnon.sol/UltraAnon.json" with { type: "json" }
import { syncInComingBalanceTree as syncIncomingBalanceTree, syncShadowTree, syncShadowBalance } from "../scripts/syncMaxing.js"
import { hashAddress, hashNullifierKey, hashNullifierValue, hashShadowBalanceTreeLeaf, hashIncomingBalanceTreeLeaf } from "../scripts/hashor.js"

import { poseidon1, poseidon2 } from "poseidon-lite";
import privateTransactionCircuit from '../circuits/privateTransfer/target/privateTransfer.json'  with { type: "json" }; //assert {type: 'json'};
// import os from 'os';
import { Noir } from "@noir-lang/noir_js";
import { UltraPlonkBackend } from '@aztec/bb.js';
import { makeNoirTest } from "../scripts/makeNoirTest.js"
window.poseidon1 = poseidon1
window.poseidon2 = poseidon2
window.syncInComingBalanceTree = syncIncomingBalanceTree
window.syncShadowTree = syncShadowTree
window.syncShadowBalance = syncShadowBalance

window.hashAddress = hashAddress

const ultraAnonAbi = UltraAnonDeploymentArtifact.abi
const ultraAnonAddress = "0xD1d17F78BC11521BD93d73a66c82e2Ec6b790b72"//UltraAnonDeploymentArtifact.
const deploymentBlock = 7793115;
window.deploymentBlock = deploymentBlock
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

    //debug shite
    window.ethers = ethers
    window.ultraAnonContract = ultraAnonContract
    window.provider = provider
    window.signer = signer
}

async function makePrivateTransfer({ amount, to, ultraAnonContract, secret }) {
    // @notice shadowBalanceTree, incomingBalanceTree are promises
    const shadowBalanceTree = syncShadowTree({ contract: ultraAnonContract, startBlock: deploymentBlock })
    const incomingBalanceTree = syncIncomingBalanceTree({ contract: ultraAnonContract, startBlock: deploymentBlock })

    window.incomingBalanceTree = incomingBalanceTree;

    const ultraAnonSenderAddress = hashAddress(secret)


    const { prevShadowNonce, prevShadowBalance } = await syncShadowBalance({ contract: ultraAnonContract, startBlock: deploymentBlock, secret: secret });
    // const prevShadowNonce = 1;
    // const prevShadowBalance = 1;
    console.log({ prevShadowNonce });
    console.log({ prevShadowBalance });
    const nullifierValue = hashNullifierValue({ balance: BigInt(prevShadowBalance) + amount, nonce: BigInt(prevShadowNonce) + 1n, secret: secret });
    const nullifierKey = hashNullifierKey({ nonce: BigInt(prevShadowNonce) + 1n, secret: secret });


    const shadowBalanceTreeLeaf = hashShadowBalanceTreeLeaf(nullifierKey, nullifierValue);
    // console.log('Generated leaf:', shadowBalanceTreeLeaf);
    console.log('First few tree elements of shadow balance tree:', (await shadowBalanceTree).elements);
    // console.log({ shadowBalanceTreeLeaf });

    let shadowBalanceTreeLeafIndex = (await shadowBalanceTree).elements.indexOf(shadowBalanceTreeLeaf);
    // console.log({ shadowBalanceTreeLeafIndex });

    // for base case where there are no leaves in the tree yet
    const defaultShadowBalanceTreeMerkleProof = Array(31).fill("0x0000000000000000000000000000000000000000000000000000000000000000");
    // use default if merkle proof if leaf isn't in tree
    let shadowBalanceTreeMerkleProof;
    if (shadowBalanceTreeLeafIndex >= 0) {
        shadowBalanceTreeMerkleProof = (await shadowBalanceTree)?.path?.(Number(shadowBalanceTreeLeafIndex))?.pathElements ?? defaultShadowBalanceTreeMerkleProof;
    } else {
        shadowBalanceTreeMerkleProof = defaultShadowBalanceTreeMerkleProof;
        // can't pass a negative number into noirJs
        shadowBalanceTreeLeafIndex = 0;
    }
    const shadowBalanceTreeRoot = (await shadowBalanceTree).root;


    const incomingBalanceTreeLeafIndex = await ultraAnonContract.merkleIndexOfAccount(ultraAnonSenderAddress) - 1n;
    console.log('First few tree elements:', (await incomingBalanceTree).elements);
    const incomingBalanceTreeMerkleProof = (await incomingBalanceTree).path(Number(incomingBalanceTreeLeafIndex)).pathElements;
    const incomingBalanceTreeRoot = (await incomingBalanceTree).root;
    // TODO: how to get?
    const incomingBalance = 102n;

    const noirJsInputs = {
        transfer_amount: ethers.toBeHex(amount),
        nullifier_value: ethers.toBeHex(nullifierValue),
        nullifier_key: ethers.toBeHex(nullifierKey),
        prev_shadow_balance_root: shadowBalanceTreeRoot,
        incoming_balance_root: incomingBalanceTreeRoot,
        recipient_account: to,
        prev_shadow_balance_merkle_proof: shadowBalanceTreeMerkleProof,
        incoming_balance_merkle_proof: incomingBalanceTreeMerkleProof,
        secret: ethers.toBeHex(secret),
        sender_account: ultraAnonSenderAddress,
        incoming_balance: ethers.toBeHex(incomingBalance),
        prev_nonce: ethers.toBeHex(prevShadowNonce),
        prev_shadow_balance: ethers.toBeHex(prevShadowBalance),
        prev_shadow_balance_index: ethers.toBeHex(shadowBalanceTreeLeafIndex),
        incoming_balance_index: ethers.toBeHex(incomingBalanceTreeLeafIndex),
    };

    console.log("creating proof");
    const proof = await makePrivateTransferNoirProof({ noirJsInputs });
    console.log("proof created");

    const contractCallInputs = {
        to: to,
        value: amount,
        nullifierValue: nullifierValue,
        nullifierKey: nullifierKey,
        shadowBalanceRoot: BigInt((await shadowBalanceTree).root),
        incomingBalanceRoot: BigInt((await incomingBalanceTree).root),
        proof: proof
    }

    console.log({ contractCallInputs })
    ultraAnonContract.privateTransfer(
        contractCallInputs.to,
        contractCallInputs.value,
        contractCallInputs.nullifierValue,
        contractCallInputs.nullifierKey,
        contractCallInputs.shadowBalanceRoot,
        contractCallInputs.incomingBalanceRoot,
        contractCallInputs.proof
    )
}
window.makePrivateTransfer = makePrivateTransfer



await main()

async function makePrivateTransferNoirProof({
    noirJsInputs
}) {
    window.noirJsInputs = noirJsInputs
    console.log({ noirJsInputs })
    console.log(makeNoirTest({ noirJsInputs }))
    const noir = new Noir(privateTransactionCircuit);

    // TODO: make this actually use dynamic number of cpus
    const backend = new UltraPlonkBackend(privateTransactionCircuit.bytecode, { threads: navigator.hardwareConcurrency });
    const { witness } = await noir.execute(noirJsInputs);
    const proof = await backend.generateProof(witness);

    const hexProof = '0x' + Array.from(proof.proof)
        .map(byte => byte.toString(16).padStart(2, '0'))
        .join('');

    // const hexPublicInputs = proof.publicInputs.map(input => {
    //     // Convert each input to hex string and ensure it's 64 chars (32 bytes) with 0x prefix
    //     let hexValue = typeof input === 'bigint'
    //         ? input.toString(16)
    //         : BigInt(input).toString(16);

    //     // Ensure 64 characters (32 bytes in hex)
    //     return '0x' + hexValue.padStart(64, '0');
    // });

    // const verifiedByJs = await backend.verifyProof(proof);
    // console.log("privateTransactionProof: ", { verifiedByJs })

    return hexProof
}
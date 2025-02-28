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

async function generateShadowBalanceMerkleProof({currentShadowNonce, secret, prevShadowBalance, shadowBalanceTree}) {
    let merkleProof;
    let leafIndex;
    if (currentShadowNonce != 0n) { // its not our first tx. so we proof like normal
        const prevNullifierValue = hashNullifierValue({ nonce: BigInt(currentShadowNonce)-1n, secret: secret, balance: BigInt(prevShadowBalance) });
        const prevNullifierKey = hashNullifierKey({ nonce: (BigInt(currentShadowNonce) -1n ), secret: secret });
        
        // leafs
        const prevShadowBalanceTreeLeaf = hashShadowBalanceTreeLeaf(prevNullifierKey, prevNullifierValue );
        const shadowBalanceTreeLeafIndex = shadowBalanceTree.elements.indexOf(ethers.zeroPadValue(ethers.toBeHex(prevShadowBalanceTreeLeaf),32));
        const shadowBalanceTreeMerkleProof = shadowBalanceTree.path(Number(shadowBalanceTreeLeafIndex)).pathElements
        merkleProof = shadowBalanceTreeMerkleProof
        leafIndex = BigInt(shadowBalanceTreeLeafIndex)
    } else {
        const emptyShadowBalanceTreeMerkleProof = Array(31).fill("0x0000000000000000000000000000000000000000000000000000000000000000");
        merkleProof =  emptyShadowBalanceTreeMerkleProof
        leafIndex = 0n 
    }
    return {merkleProof, leafIndex}
}

async function generateIncomingBalanceMerkleProof({incomingBalanceTree, ultraAnonContract, ultraAnonSenderAddress}) {
    const incomingBalanceTreeLeafIndex = await ultraAnonContract.merkleIndexOfAccount(ultraAnonSenderAddress) - 1n; // -1n because i set up mapping to add 1 because mappings return 0 by default. So 0=doesn't exist, realIndex=index-1n 
    console.log({incomingBalanceTreeLeafIndex})
    const incomingBalanceTreeMerkleProof = incomingBalanceTree.path(Number(incomingBalanceTreeLeafIndex)).pathElements;
    return {merkleProof: incomingBalanceTreeMerkleProof, leafIndex: BigInt(incomingBalanceTreeLeafIndex)}
}

async function makePrivateTransfer({ amount, to, ultraAnonContract, secret }) {
    ethers.assert(ethers.isAddress(to), "not an address or checksum failed")
    //sync tress
    const shadowBalanceTree = syncShadowTree({ contract: ultraAnonContract, startBlock: deploymentBlock })
    const incomingBalanceTree = syncIncomingBalanceTree({ contract: ultraAnonContract, startBlock: deploymentBlock })

    // sync shadow balance
    const { currentNonce: currentShadowNonce, shadowBalance:prevShadowBalance } = await syncShadowBalance({ contract: ultraAnonContract, startBlock: deploymentBlock, secret: secret });

    // hashing current nullifier
    const ultraAnonSenderAddress = hashAddress(secret)
    const nullifierValue = hashNullifierValue({ nonce: BigInt(currentShadowNonce) , secret: secret, balance: BigInt(prevShadowBalance) + amount });
    const nullifierKey = hashNullifierKey({ nonce: (BigInt(currentShadowNonce) ), secret: secret });
    
    const {merkleProof:shadowBalanceTreeMerkleProof, leafIndex:shadowBalanceTreeLeafIndex} = await generateShadowBalanceMerkleProof({
        currentShadowNonce: currentShadowNonce, 
        secret: secret, 
        prevShadowBalance: prevShadowBalance, 
        shadowBalanceTree: await shadowBalanceTree
    }) 

    const {merkleProof: incomingBalanceTreeMerkleProof,leafIndex:incomingBalanceTreeLeafIndex } = await generateIncomingBalanceMerkleProof({
        incomingBalanceTree: await incomingBalanceTree, 
        ultraAnonContract: ultraAnonContract,
        ultraAnonSenderAddress: ultraAnonSenderAddress
    })

    const incomingBalance = await ultraAnonContract.incomingBalance(ultraAnonSenderAddress);

    const noirJsInputs = {
        transfer_amount: ethers.toBeHex(amount),

        nullifier_value: ethers.toBeHex(nullifierValue),
        nullifier_key: ethers.toBeHex(nullifierKey),

        prev_shadow_balance_root: (await shadowBalanceTree).root,
        incoming_balance_root: (await incomingBalanceTree).root,

        recipient_account: to,

        prev_shadow_balance_merkle_proof: shadowBalanceTreeMerkleProof,
        incoming_balance_merkle_proof: incomingBalanceTreeMerkleProof,

        secret: ethers.toBeHex(secret),
        sender_account: ultraAnonSenderAddress,

        incoming_balance: ethers.toBeHex(incomingBalance),

        
        nonce: ethers.toBeHex(currentShadowNonce),
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

async function makePrivateTransferNoirProof({noirJsInputs}) {
    window.noirJsInputs = noirJsInputs
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
    window.poseidon1 = poseidon1
    window.poseidon2 = poseidon2
    window.syncInComingBalanceTree = syncIncomingBalanceTree
    window.syncShadowTree = syncShadowTree
    window.syncShadowBalance = syncShadowBalance
    window.hashAddress = hashAddress
    window.hashNullifierKey =hashNullifierKey
}

await main()


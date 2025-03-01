// node_modules
import { ethers } from "ethers";
import { poseidon1, poseidon2 } from "poseidon-lite";

// abis, circuits
import UltraAnonDeploymentArtifact from "../artifacts/contracts/UltraAnon.sol/UltraAnon.json" with { type: "json" }
import privateTransactionCircuit from '../circuits/privateTransfer/target/privateTransfer.json'  with { type: "json" }; //assert {type: 'json'};
import publicTransactionCircuit from '../circuits/publicTransfer/target/publicTransfer.json'  with { type: "json" }; //assert {type: 'json'};

// local imports
import { syncInComingBalanceTree as syncIncomingBalanceTree, syncShadowTree, syncShadowBalance } from "./syncMaxing.js"
import { hashAddress, hashNullifierKey, hashNullifierValue, hashShadowBalanceTreeLeaf, hashIncomingBalanceTreeLeaf } from "./hashor.js"
import { makeNoirTest } from "./makeNoirTest.js"


// noir
import { Noir } from "@noir-lang/noir_js";
import { UltraPlonkBackend } from '@aztec/bb.js';


async function generateShadowBalanceMerkleProof({ currentShadowNonce, secret, prevShadowBalance, shadowBalanceTree }) {
    let merkleProof;
    let leafIndex;
    if (currentShadowNonce != 0n) { // its not our first tx. so we proof like normal
        const prevNullifierValue = hashNullifierValue({ nonce: BigInt(currentShadowNonce) - 1n, secret: secret, balance: BigInt(prevShadowBalance) });
        const prevNullifierKey = hashNullifierKey({ nonce: (BigInt(currentShadowNonce) - 1n), secret: secret });

        // leafs
        const prevShadowBalanceTreeLeaf = hashShadowBalanceTreeLeaf(prevNullifierKey, prevNullifierValue);

        const shadowBalanceTreeLeafIndex = shadowBalanceTree.elements.indexOf(ethers.zeroPadValue(ethers.toBeHex(prevShadowBalanceTreeLeaf), 32));
        const shadowBalanceTreeMerkleProof = shadowBalanceTree.path(Number(shadowBalanceTreeLeafIndex)).pathElements

        merkleProof = shadowBalanceTreeMerkleProof
        leafIndex = BigInt(shadowBalanceTreeLeafIndex)
    } else {
        const emptyShadowBalanceTreeMerkleProof = Array(31).fill("0x0000000000000000000000000000000000000000000000000000000000000000");
        merkleProof = emptyShadowBalanceTreeMerkleProof
        leafIndex = 0n
    }
    return { merkleProof, leafIndex }
}

async function generateIncomingBalanceMerkleProof({ incomingBalanceTree, ultraAnonContract, ultraAnonSenderAddress }) {
    const incomingBalanceTreeLeafIndex = await ultraAnonContract.merkleIndexOfAccount(ultraAnonSenderAddress) - 1n; // -1n because i set up mapping to add 1 because mappings return 0 by default. So 0=doesn't exist, realIndex=index-1n 
    const incomingBalanceTreeMerkleProof = incomingBalanceTree.path(Number(incomingBalanceTreeLeafIndex)).pathElements;
    console.log({incomingBalanceTreeLeafIndex})
    const leafFromJsTree = incomingBalanceTree.elements[Number(incomingBalanceTreeLeafIndex)]
    window.incomingBalanceTree =  incomingBalanceTree
    console.log({leafFromJsTree})
    return { merkleProof: incomingBalanceTreeMerkleProof, leafIndex: BigInt(incomingBalanceTreeLeafIndex) }
}

async function generateProofInputs({ amount, to, ultraAnonContract, secret, deploymentBlock }) {
    ethers.assert(typeof (deploymentBlock) === "number", "deployment block not a number")
    ethers.assert(ethers.isAddress(to), "not an address or checksum failed")
    //sync tress
    const shadowBalanceTree = syncShadowTree({ contract: ultraAnonContract, startBlock: deploymentBlock })
    const incomingBalanceTree = syncIncomingBalanceTree({ contract: ultraAnonContract, startBlock: deploymentBlock })

    // sync shadow balance
    const { currentNonce: currentShadowNonce, shadowBalance: prevShadowBalance } = await syncShadowBalance({ contract: ultraAnonContract, startBlock: deploymentBlock, secret: secret });

    // hashing current nullifier
    const ultraAnonSenderAddress = hashAddress(secret)
    const nullifierValue = hashNullifierValue({ nonce: BigInt(currentShadowNonce), secret: secret, balance: BigInt(prevShadowBalance) + amount });
    const nullifierKey = hashNullifierKey({ nonce: (BigInt(currentShadowNonce)), secret: secret });

    const { merkleProof: shadowBalanceTreeMerkleProof, leafIndex: shadowBalanceTreeLeafIndex } = await generateShadowBalanceMerkleProof({
        currentShadowNonce: currentShadowNonce,
        secret: secret,
        prevShadowBalance: prevShadowBalance,
        shadowBalanceTree: await shadowBalanceTree
    })

    const { merkleProof: incomingBalanceTreeMerkleProof, leafIndex: incomingBalanceTreeLeafIndex } = await generateIncomingBalanceMerkleProof({
        incomingBalanceTree: await incomingBalanceTree,
        ultraAnonContract: ultraAnonContract,
        ultraAnonSenderAddress: ultraAnonSenderAddress
    })

    const incomingBalance = await ultraAnonContract.incomingBalance(ultraAnonSenderAddress);
    const leafHashedJs = poseidon2([ultraAnonSenderAddress,incomingBalance])
    console.log({leafHashedJs})
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

    return { ultraAnonSenderAddress, noirJsInputs, nullifierValue, nullifierKey, shadowBalanceTree: await shadowBalanceTree, incomingBalanceTree: await incomingBalanceTree }

}

async function makePrivateTransferNoirProof({ noirJsInputs }) {
    console.log(makeNoirTest({ noirJsInputs }))


    const noir = new Noir(privateTransactionCircuit);

    // TODO: make this actually use dynamic number of cpus
    const backend = new UltraPlonkBackend(privateTransactionCircuit.bytecode, { threads: navigator.hardwareConcurrency });
    const { witness } = await noir.execute(noirJsInputs);
    const proof = await backend.generateProof(witness);
    // console.log({ proof })
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

    // return hexPublicInputs
    return proof.proof
}

async function makePublicTransferNoirProof({ noirJsInputs }) {
    const noir = new Noir(publicTransactionCircuit);
    const backend = new UltraPlonkBackend(publicTransactionCircuit.bytecode, { threads: navigator.hardwareConcurrency });
    const { witness } = await noir.execute(noirJsInputs);
    const proof = await backend.generateProof(witness);
    console.log({ proof })

    return proof.proof
}

export async function privateTransfer({ amount, to, ultraAnonContract, secret, deploymentBlock }) {

    const {
        noirJsInputs,
        nullifierValue,
        nullifierKey,
        shadowBalanceTree,
        incomingBalanceTree
    } = await generateProofInputs({ amount, to, ultraAnonContract, secret, deploymentBlock })

    console.log("creating proof");
    const proof = await makePrivateTransferNoirProof({ noirJsInputs });
    console.log("proof created");

    const contractCallInputs = {
        to: to,
        value: amount,
        nullifierValue: nullifierValue,
        nullifierKey: nullifierKey,
        shadowBalanceRoot: BigInt(shadowBalanceTree.root),
        incomingBalanceRoot: BigInt(incomingBalanceTree.root),
        proof: proof
    }


    try {
        const tx = await relayPrivateTransferRequest(contractCallInputs)
        return tx

    } catch {
        const tx = await ultraAnonContract.privateTransfer(
            contractCallInputs.to,
            contractCallInputs.amount,
            contractCallInputs.nullifierValue,
            contractCallInputs.nullifierKey,
            contractCallInputs.shadowBalanceRoot,
            contractCallInputs.incomingBalanceRoot, 
            contractCallInputs.proof
        )
        return (await tx.wait(1)).hash

    }

    // ultraAnonContract.privateTransfer(
    //     contractCallInputs.to,
    //     contractCallInputs.value,
    //     contractCallInputs.nullifierValue,
    //     contractCallInputs.nullifierKey,
    //     contractCallInputs.shadowBalanceRoot,
    //     contractCallInputs.incomingBalanceRoot,
    //     contractCallInputs.proof
    // )
}

async function relayPrivateTransferRequest(contractCallInputs) {
    console.log({ contractCallInputs });
    let proof = ethers.hexlify(contractCallInputs.proof);
    // Format the request body according to the Rust server's expected structure
    const requestBody = {
        to: contractCallInputs.to,
        value: BigInt(contractCallInputs.value).toString(),
        nullifier_value: BigInt(contractCallInputs.nullifierValue).toString(),
        nullifier_key: BigInt(contractCallInputs.nullifierKey).toString(),
        shadow_balance_root: BigInt(contractCallInputs.shadowBalanceRoot).toString(),
        incoming_balance_root: BigInt(contractCallInputs.incomingBalanceRoot).toString(),
        proof: proof.startsWith('0x') ? proof.slice(2) : proof
    };


    try {
        const response = await fetch('http://164.92.84.12:8000/private_transfer', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody),
        });

        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const data = await response.json();
        console.log('Private transfer submitted successfully:', data);
        return data;
    } catch (error) {
        console.error('Error sending private transfer:', error);
        throw error;
    }

}


export async function publicTransfer({ amount, to, ultraAnonContract, secret, deploymentBlock }) {

    const {
        noirJsInputs,
        nullifierValue,
        nullifierKey,
        shadowBalanceTree,
        incomingBalanceTree,
        ultraAnonSenderAddress
    } = await generateProofInputs({ amount, to, ultraAnonContract, secret, deploymentBlock })

    console.log("creating proof");
    const proof = await makePublicTransferNoirProof({ noirJsInputs });
    console.log("proof created");

    const contractCallInputs = {
        to: to,
        value: amount,
        nullifierValue: nullifierValue,
        nullifierKey: nullifierKey,
        shadowBalanceRoot: BigInt(shadowBalanceTree.root),
        incomingBalanceRoot: BigInt(incomingBalanceTree.root),
        owner: ultraAnonSenderAddress,
        proof: proof
    }

    console.log({ contractCallInputs })
    try {
        const tx = await relayPublicTransferRequest(contractCallInputs)
        return tx

    } catch {
        const tx = await ultraAnonContract.publicTransfer(
            contractCallInputs.to,
            contractCallInputs.amount,
            contractCallInputs.nullifierValue,
            contractCallInputs.nullifierKey,
            contractCallInputs.shadowBalanceRoot,
            contractCallInputs.incomingBalanceRoot, 
            contractCallInputs.owner,
            contractCallInputs.proof
        )
        return (await tx.wait(1)).hash

    }
    
    // ultraAnonContract.publicTransfer(
    //     contractCallInputs.to,
    //     contractCallInputs.value,
    //     contractCallInputs.nullifierValue,
    //     contractCallInputs.nullifierKey,
    //     contractCallInputs.shadowBalanceRoot,
    //     contractCallInputs.incomingBalanceRoot,
    //     contractCallInputs.owner,
    //     contractCallInputs.proof
    // )

}

async function relayPublicTransferRequest(contractCallInputs) {
    console.log({ contractCallInputs });
    let proof = ethers.hexlify(contractCallInputs.proof);
    // Format the request body according to the Rust server's expected structure
    const requestBody = {
        to: contractCallInputs.to,
        value: BigInt(contractCallInputs.value).toString(),
        nullifier_value: BigInt(contractCallInputs.nullifierValue).toString(),
        nullifier_key: BigInt(contractCallInputs.nullifierKey).toString(),
        shadow_balance_root: BigInt(contractCallInputs.shadowBalanceRoot).toString(),
        incoming_balance_root: BigInt(contractCallInputs.incomingBalanceRoot).toString(),
        owner: contractCallInputs.owner,
        proof: proof.startsWith('0x') ? proof.slice(2) : proof
    };

    console.log({ requestBody })

    try {
        const response = await fetch('http://164.92.84.12:8000/public_transfer', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody),
        });

        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        const data = await response.json();
        console.log('Public transfer submitted successfully:', data);
        return data;
    } catch (error) {
        console.error('Error sending public transfer:', error);
        throw error;
    }
}
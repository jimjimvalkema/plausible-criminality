import { MerkleTree } from 'fixed-merkle-tree';
import { poseidon2, poseidon3 } from 'poseidon-lite';
import { ethers } from 'ethers';

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n
const MERKLETREEDEPTH = 32
const ZERO = BigInt(ethers.keccak256(new TextEncoder().encode("tornado"))) % FIELD_SIZE //tornadocash wow so cool edgy!!!
//const HASH_FUNCTION = (left, right) => ethers.toBeHex(poseidon2([ethers.toBigInt(left), ethers.toBigInt(right)]))
const HASH_FUNCTION = (left, right) => ethers.zeroPadValue(ethers.toBeHex(poseidon2([BigInt(left), BigInt(right)])), 32)

/**
 * @typedef {import('./File1.js').MyObject1} ProofPath
 * @param {ethers.BytesLike[]} nonEmptyLeaves 
 * @param {ethers.BytesLike} leaf 
 * @returns {ProofPath}
 */
function getMerkleProof(nonEmptyLeaves, leafIndex) {
    const tree = new MerkleTree(MERKLETREEDEPTH, nonEmptyLeaves, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    const proofPath = tree.path(leafIndex)
    return { proof: proofPath.pathElements, leafIndex, root: proofPath.pathRoot }
}

// I hate js idk if it's okay to change these to var but I don't want to shoot myself in the foot
// so here is a scope

// previous values
const secret = 0x01;
const prev_nonce = 0x00;
console.log({ prev_nonce });
const prev_priv_balance = 0x00;
const prev_nullifier_key = HASH_FUNCTION(prev_nonce, secret);
const prev_nullifier_value = ethers.zeroPadValue(ethers.toBeHex(poseidon3([BigInt(prev_priv_balance), BigInt(prev_nonce), BigInt(secret)])), 32);
const prev_leafToProve = HASH_FUNCTION(prev_nullifier_key, prev_nullifier_value);
console.log("initial shadow tree leaf to prove: ", { prev_leafToProve });
const prev_leaves = [prev_leafToProve, "0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000003", "0x0000000000000000000000000000000000000000000000000000000000000004"].map((i) => ethers.zeroPadValue(i, 32))
const prev_leafIndex = prev_leaves.indexOf(prev_leafToProve);
console.log("prev shadow balance index: ", { prev_leafIndex });
const prev_shadow_proof = getMerkleProof(prev_leaves, prev_leafIndex);
console.log({ prev_shadow_proof });

// current values (after sending 5)
const nonce = 0x01;
const priv_balance = 0x05;
console.log({ priv_balance });
const nullifier_key = HASH_FUNCTION(nonce, secret);
const nullifier_value = ethers.zeroPadValue(ethers.toBeHex(poseidon3([BigInt(priv_balance), BigInt(nonce), BigInt(secret)])), 32);
console.log({ nullifier_key });
console.log({ nullifier_value });
const leafToProve = HASH_FUNCTION(nullifier_key, nullifier_value);
console.log("current shadow tree leaf to prove: ", { leafToProve });
const leaves = [leafToProve, "0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000003", "0x0000000000000000000000000000000000000000000000000000000000000004"].map((i) => ethers.zeroPadValue(i, 32))
const leafIndex = leaves.indexOf(leafToProve);
const shadow_proof = getMerkleProof(leaves, leafIndex);
console.log({ shadow_proof });


// public balance tree (doesn't change before & after txn)
const account = ethers.zeroPadValue(ethers.hexlify(new TextEncoder().encode("Go team!")), 32)
console.log({ account });
const balance = ethers.zeroPadValue(ethers.toBeHex(10n), 32);
console.log({ balance });
const public_leafToProve = HASH_FUNCTION(account, balance);
console.log("public balance tree leaf to prove: ", { public_leafToProve });
const public_leaves = [public_leafToProve, "0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000003", "0x0000000000000000000000000000000000000000000000000000000000000004"].map((i) => ethers.zeroPadValue(i, 32))
const public_leafIndex = public_leaves.indexOf(public_leafToProve);
console.log({ public_leafIndex });
const public_proof = getMerkleProof(public_leaves, public_leafIndex);
console.log({ public_proof });


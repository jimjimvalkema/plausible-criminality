import { MerkleTree } from 'fixed-merkle-tree';
import { poseidon2 } from 'poseidon-lite';
import { ethers } from 'ethers';

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n
const MERKLETREEDEPTH = 32
const ZERO = BigInt(ethers.keccak256(new TextEncoder().encode("tornado"))) % FIELD_SIZE //tornadocash wow so cool edgy!!!
//const HASH_FUNCTION = (left, right) => ethers.toBeHex(poseidon2([ethers.toBigInt(left), ethers.toBigInt(right)]))
const HASH_FUNCTION = (left, right) => ethers.toBeHex(poseidon2([BigInt(left), BigInt(right)]))

/**
 * @typedef {import('./File1.js').MyObject1} ProofPath
 * @param {ethers.BytesLike[]} nonEmptyLeaves 
 * @param {ethers.BytesLike} leaf 
 * @returns {ProofPath}
 */
function getMerkleProof(nonEmptyLeaves, leafIndex) {
    const tree = new MerkleTree(MERKLETREEDEPTH, nonEmptyLeaves, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    const proofPath = tree.path(leafIndex) 
    return {proof: proofPath.pathElements, leafIndex, root:proofPath.pathRoot}
}

const leafToProof = ethers.zeroPadValue(ethers.hexlify(new TextEncoder().encode("hiJoss")),32)
const leaves = [leafToProof,"0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000003", "0x0000000000000000000000000000000000000000000000000000000000000004"].map((i)=>ethers.zeroPadValue(i,32))
const leafIndex = leaves.indexOf(leafToProof)
const proof = getMerkleProof(leaves, leafIndex)

console.log({proof})
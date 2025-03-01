import { MerkleTree } from 'fixed-merkle-tree';
import { poseidon2 } from 'poseidon-lite';
import { ethers } from 'ethers';
import * as fs from 'node:fs/promises'

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n
const MERKLETREEDEPTH = 32
const ZERO = BigInt(ethers.keccak256(new TextEncoder().encode("tornado"))) % FIELD_SIZE

function formatSolidity(levels) {
    let solidityStr = ""
    for (const [i, level] of levels.entries()) {
        solidityStr += `else if (i == ${i}) return uint256(${level});\n`
    }
    return solidityStr
}


// reproduce tree
const hashFunction = (left, right) => poseidon2([left, right])
const leaves = []
const tree = new MerkleTree(MERKLETREEDEPTH, leaves, { hashFunction, zeroElement: ZERO })
const levels = tree.zeros.map((level)=>ethers.zeroPadValue(ethers.toBeHex(level)))
await fs.writeFile(`${import.meta.dirname}/out/levels.sol.txt`, formatSolidity(levels))
await fs.writeFile(`${import.meta.dirname}/out/levels.json`, JSON.stringify(levels))
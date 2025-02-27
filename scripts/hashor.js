//aaah am hashingggg
import { ethers } from "ethers"
import { poseidon3, poseidon2, poseidon1 } from 'poseidon-lite';

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n
const MERKLETREEDEPTH = 31
const ZERO = ethers.toBeHex(BigInt(ethers.keccak256(new TextEncoder().encode("tornado"))) % FIELD_SIZE) //tornadocash wow so cool edgy!!!


export function hashAddress(secret) {
    const hash = poseidon1([secret])
    const slicedTo20Bytes = ethers.hexlify(ethers.toBeArray(hash).slice(0, 20))
    return slicedTo20Bytes
}

export function hashIncomingBalanceTreeLeaf({ account, balance }) {
    return poseidon2([account, balance])
}

export function hashShadowBalanceTreeLeaf(nullifierKey, nullifierValue) {
    return poseidon2([nullifierKey, nullifierValue])
}

//let prev_nullifier_key = poseidon::bn254::hash_2([prev_nonce, secret]);
//let prev_nullifier_value = poseidon::bn254::hash_3([prev_shadow_balance, prev_nonce, secret]);

export function hashNullifierKey({ nonce, secret }) {
    return poseidon2([nonce, secret])
}

export function hashNullifierValue({ balance, nonce, secret }) {
    return poseidon3([balance, nonce, secret])
}
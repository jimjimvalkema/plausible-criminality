/// ooooooooooooo am synciiiinggg
import { MerkleTree } from 'fixed-merkle-tree';
import { ethers, wordlists } from "ethers"
import { poseidon2 } from 'poseidon-lite';

import {hashNullifierKey} from "../scripts/hashor.js"

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n
const MERKLETREEDEPTH = 31
const ZERO = ethers.toBeHex(BigInt(ethers.keccak256(new TextEncoder().encode("tornado"))) % FIELD_SIZE) //tornadocash wow so cool edgy!!!
//const HASH_FUNCTION = (left, right) => ethers.toBeHex(poseidon2([ethers.toBigInt(left), ethers.toBigInt(right)]))
const HASH_FUNCTION = (left, right) => ethers.toBeHex(poseidon2([BigInt(left), BigInt(right)]))




/**
 * 
 * @param {{contract:ethers.Contract}} param0 
 */
async function queryEventInChunks({chunksize=5000,filter,startBlock,contract}){

    const provider = contract.runner.provider
    const lastBlock = await provider.getBlockNumber("latest")
    const numIters = Math.ceil((lastBlock-startBlock)/chunksize)
    const allEvents = []
    console.log("syncing events: ",{lastBlock,startBlock,chunksize,numIters})
    for (let index = 0; index < numIters; index++) {
        const start = index*chunksize + startBlock
        const stop =  (start + chunksize) > lastBlock ? lastBlock :  (start + chunksize)
        const events =  await contract.queryFilter(filter,start,stop)
        allEvents.push(events)
    }
    return allEvents.flat()

}
/**
 *  
 * @typedef {{leafHash:BigInt, index: BigInt, timeStamp:BigInt}} leaf
 * @param {*} param0 
 * @returns {Promise<leaf[]>} leaves
 */
export async function getLeaves({contract, startBlock, eventName, chunksize=5000}) {
    const eventFilter = contract.filters[eventName]()
    const newLeafEvents = await queryEventInChunks({chunksize:chunksize,filter:eventFilter,startBlock:startBlock,contract:contract})
    const abiCoder = new ethers.AbiCoder()
    const types = ["uint32", "uint256"]
    const leaves = newLeafEvents.map((event)=> {
        const decodedData = abiCoder.decode(types,event.data)
        const leafHash = BigInt(event.topics[1])
        const index = decodedData[0]
        const timeStamp = decodedData[1]
        return {leafHash, index , timeStamp}
    })
    return leaves
}


export async function syncInComingBalanceTree({contract, startBlock, eventScanChunksize=5000}) {
    //event scannoooor
    const newLeaves = await getLeaves({contract, startBlock, eventName:"IncomBalNewLeaf", chunksize:eventScanChunksize}) 
    const leafUpdates = await getLeaves({contract, startBlock, eventName:"IncomBalUpdatedLeaf", chunksize:eventScanChunksize}) 

 
    
    // update all newLeafes with leafUpdates and put them in currentLeaves (<- the real leaves of the current tree)
    const currentLeaves = newLeaves;
    for (const leafUpdate of leafUpdates) {
        const leafUpdateIsNewer = (leafUpdate.timeStamp >  currentLeaves[leafUpdate.index].timeStamp) 
        ethers.assert(leafUpdateIsNewer, "leaf update is not newer this shouldn't happen")
        if (leafUpdateIsNewer) {
            ethers.assert(currentLeaves[leafUpdate.index].index === leafUpdate.index, "tried to replace the wrong index this shouldn't happen")
            currentLeaves[leafUpdate.index] = leafUpdate
        }
    }

    // we only want the hashes now
    const leavesOnlyHashes = currentLeaves.map((leaf)=>ethers.toBeHex(leaf.leafHash));
    const tree = new MerkleTree(MERKLETREEDEPTH, leavesOnlyHashes, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    return tree
}

export async function syncShadowTree({contract, startBlock, eventScanChunksize=5000}) {
    //event scannoooor
    const leaves = await getLeaves({contract, startBlock, eventName:"ShadowNewLeaf", chunksize:eventScanChunksize}) 
    // we only want the hashes now
    const leavesOnlyHashes = leaves.map((leaf)=>ethers.toBeHex(leaf.leafHash));
    const tree = new MerkleTree(MERKLETREEDEPTH, leavesOnlyHashes, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    return tree
}

export async function syncShadowBalance({contract, startBlock, secret, noncesPerScan=20,chunksize=5000  }) {
    let lastNullifierFound;
    let isLastNullifierFound = false
    let lastNonceFound = 0n
    const allNullifierKeysAndAmounts = []
    while (isLastNullifierFound === false) {
        const nonces = (new Array(noncesPerScan)).fill(0).map((v,i)=> lastNonceFound+BigInt(i))

        // TODO  change start block
        const nullifierKeys = await scanForNullifierKeys({contract, startBlock, nonces, secret,chunksize })
        lastNullifierFound = nullifierKeys[nullifierKeys.length-1]
        if(lastNullifierFound===undefined) {
            lastNullifierFound = {nonce:0n, blockNumber:startBlock}

        }



        // cant have a nonce that is higher appear in a block before a lower nonce
        startBlock = lastNullifierFound.blockNumber

        allNullifierKeysAndAmounts.push(nullifierKeys)

        if (nullifierKeys.length < noncesPerScan) {
            isLastNullifierFound = true
            break;
        }
    }
    //[1,2,3,4,5].reduce((total, val) => total + val,0);
    const totalShadowBalance = allNullifierKeysAndAmounts.flat().reduce((total,nullifierKey)=>total += nullifierKey.amountSent, 0n)
    return {latestNonce: lastNullifierFound.nonce, shadowBalance: totalShadowBalance}
    
}

export async function scanForNullifierKeys({contract, startBlock, nonces, secret,chunksize=5000 }) {
    const nullifierKeys = nonces.map((nonce)=>hashNullifierKey({nonce, secret}))

    //scanning
    const eventName = "NullifierAdded"
    const eventFilter = contract.filters[eventName]([...nullifierKeys])
    const events = await queryEventInChunks({chunksize:chunksize,filter:eventFilter,startBlock:startBlock,contract:contract})
    
    // decoding
    const abiCoder = new ethers.AbiCoder()
    const types = ["uint256"]
    const nullifierKeysWithAmounts = events.map((event, i)=>{
        const nonce = nonces[i]
        const nullifierKey = BigInt(event.topics[1])
        const decodedData = abiCoder.decode(types,event.data)
        const amountSent = decodedData[0]
        return {nullifierKey, amountSent, nonce, blockNumber: event.blockNumber}
    })

    return nullifierKeysWithAmounts
}

//leaves = await syncNewLeafs({contract:ultraAnonContract, startBlock:7791355, eventName:"IncomBalUpdatedLeaf"})

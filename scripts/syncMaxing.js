/// ooooooooooooo am synciiiinggg
import { ethers } from "ethers"
import { MerkleTree } from 'fixed-merkle-tree';
import { poseidon2 } from 'poseidon-lite';

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
export async function getLeaves({contract, startBlock, eventName}) {
    const eventFilter = contract.filters[eventName]()
    const newLeafEvents =await  queryEventInChunks({chunksize:5000,filter:eventFilter,startBlock:startBlock,contract:contract})
    const abiCoder = new ethers.AbiCoder()
    const types = ["uint32", "uint256"]
    const leaves = newLeafEvents.map((event)=> {
        const decodedData = abiCoder.decode(types,event.data)
        return {"leafHash":BigInt(event.topics[1]), "index": decodedData[0], "timeStamp":decodedData[1]}
    })
    return leaves
}


export async function syncInComingBalanceTree({contract, startBlock}) {
    const newLeaves = await getLeaves({contract, startBlock, eventName:"IncomBalNewLeaf"}) 
    const leafUpdates = await getLeaves({contract, startBlock, eventName:"IncomBalUpdatedLeaf"}) 
    //console.log({leafUpdates, newLeaves})
    const currentLeaves = newLeaves;
    for (const leafUpdate of leafUpdates) {
        const leafUpdateIsNewer = (leafUpdate.timeStamp >  currentLeaves[leafUpdate.index].timeStamp) 
        ethers.assert(leafUpdateIsNewer, "leaf update is not newer this shouldn't happen")
        if (leafUpdateIsNewer) {
            ethers.assert(currentLeaves[leafUpdate.index].index === leafUpdate.index, "tried to replace the wrong index this shouldn't happen")
            currentLeaves[leafUpdate.index] = leafUpdate
        }
    }
    const leavesOnlyHashes = currentLeaves.map((leaf)=>ethers.toBeHex(leaf.leafHash));
    const tree = new MerkleTree(MERKLETREEDEPTH, leavesOnlyHashes, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    return tree
}

export async function syncShadowTree({contract, startBlock}) {
    const leaves = await getLeaves({contract, startBlock, eventName:"ShadowNewLeaf"}) 
    const leavesOnlyHashes = leaves.map((leaf)=>ethers.toBeHex(leaf.leafHash));
    const tree = new MerkleTree(MERKLETREEDEPTH, leavesOnlyHashes, { hashFunction: HASH_FUNCTION, zeroElement: ZERO })
    return tree
}

//leaves = await syncNewLeafs({contract:ultraAnonContract, startBlock:7791355, eventName:"IncomBalUpdatedLeaf"})

/// ooooooooooooo am synciiiinggg
import { ethers } from "ethers"

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

async function syncNewLeafs({contract, startBlock, eventName}) {
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

//leaves = await syncNewLeafs({contract:ultraAnonContract, startBlock:7791355, eventName:"IncomBalUpdatedLeaf"})

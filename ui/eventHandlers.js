import { ethers, hexlify } from "ethers"

import { hashAddress, getSafeRandomNumber } from "../scripts/hashor"
import {syncShadowBalance} from "../scripts/syncMaxing"
import { privateTransfer, publicTransfer } from "../scripts/transactionBuilder"

async function mintTokensHandler({ultraAnonContract, secret, deploymentBlock}) {
    console.log({secret})
    const address = hashAddress(secret) 
    const tx = await ultraAnonContract.mint(address,ethers.parseUnits("100", 18))

    await newTx({txhash:tx.hash,address,contractAddress:ultraAnonContract.target,txType:"mint"})
    await tx.wait(1)
    updateBalances({secret, ultraAnonContract, deploymentBlock})

}

export function setEventHandlers({ultraAnonContract, deploymentBlock}) {
    const pubTxsUl = document.getElementById("allPublicTransfersUl")
    const privTxsUl = document.getElementById("allPrivateTransfersUl")

    const mintToken = document.getElementById("mintToken")


    const contractAddress = ultraAnonContract.target

    const importPrivateKeyInput = document.getElementById("importPrivateKeyInput")
    const importPrivateKeyBtn = document.getElementById("importPrivateKeyBtn")

    const copyAddressBtn = document.getElementById("copyAddressBtn")
    const copyPrivatekeyBtn = document.getElementById("copyPrivatekeyBtn")

    const accountSelectorEl = document.getElementById("accountSelector")
    const generateAddressBtn = document.getElementById("generateNewAddress")
    const privateTransferBtn = document.getElementById("privateTransferBtn")
    const publicTransferBtn = document.getElementById("publicTransferBtn")

    const recipientAddressInput = document.getElementById("recipientAddressInput")
    const amountInput = document.getElementById("amountInput")

    copyAddressBtn.addEventListener("click", async ()=> copyAddressBtnHandler({accountSelectorEl}))
    copyPrivatekeyBtn.addEventListener("click", async ()=> copySecretBtnHandler({accountSelectorEl}))

    generateAddressBtn.addEventListener("click", async ()=>generateAddressHandler({ultraAnonContract, accountSelectorEl}))
    accountSelectorEl.addEventListener("change",async (event)=>accountSelectorHandler({pubTxsUl, privTxsUl,event, accountSelectorEl, ultraAnonContract, deploymentBlock}))
    
    publicTransferBtn.addEventListener("click", async ()=>transferPubliclyHandler({allPublicTransfersUl: pubTxsUl,accountSelectorEl, recipientAddressInput, amountInput, ultraAnonContract, deploymentBlock}))
    privateTransferBtn.addEventListener("click", async ()=>transferPrivatelyHandler({allPrivateTransfersUl: privTxsUl, accountSelectorEl, recipientAddressInput, amountInput, ultraAnonContract, deploymentBlock}))
    
    importPrivateKeyBtn.addEventListener("click", async ()=>addNewAccount({secret:importPrivateKeyInput.value,contractAddress, accountSelectorEl}))

    mintToken.addEventListener("click",async ()=>mintTokensHandler({ultraAnonContract, secret:accountSelectorEl.value, deploymentBlock}))
    updateAccountSelector({accountSelectorEl, contractAddress: contractAddress})

}

function messageUi(message) {
    console.log("message: ", message)
    setClass({className:"message", value:message})
}

function copyAddressBtnHandler({accountSelectorEl}) {
    const secret = accountSelectorEl.value
    const address = hashAddress(secret)
    navigator.clipboard.writeText(address);
}

function copySecretBtnHandler({accountSelectorEl}) {
    const secret = accountSelectorEl.value
    navigator.clipboard.writeText(secret);
}


function addSecretLocalStorage({secret, address, contractAddress}) {
    let allSecret = JSON.parse(localStorage.getItem(contractAddress))//localStorage.setItem(contractAddress, JSON.stringify([1,2]))
    if (!allSecret) {
        allSecret = {}
    }
    allSecret[address] = {secret: ethers.toBeHex(secret)}
    localStorage.setItem(contractAddress, JSON.stringify(allSecret))
}



/**
 * 
 * @param {{contractAddress, accountSelectorEl:Element}} param0 
 */
function updateAccountSelector({contractAddress, accountSelectorEl, selectSecret}) {
    const allSecrets = JSON.parse(localStorage.getItem(contractAddress));
    if (!selectSecret) {
        const allAddresses = allSecrets ? Object.keys(allSecrets) : false
        const firstSecret = allAddresses ? allSecrets[allAddresses[0]].secret : ""
        selectSecret = firstSecret 
    }

    // remove all option except the first one
    const optionIndexes = [...accountSelectorEl.options].map((v,i)=>i)
    optionIndexes.slice(1).forEach((index)=>accountSelectorEl.options.remove(index));
    for (const address in allSecrets) {
        const secret = allSecrets[address].secret
        const option = document.createElement("option")
        option.value = secret
        option.innerText = address
        accountSelectorEl.appendChild(option)
    }
    accountSelectorEl.value = selectSecret
    const changeEvent = new Event("change");
    accountSelectorEl.dispatchEvent(changeEvent)

}

function setClass({className, value}) {
    for (const element of document.getElementsByClassName(className)) {
        element.innerText = value
    } 
}


function generateAddressHandler({ultraAnonContract, accountSelectorEl}) {
    const contractAddress = ultraAnonContract.target
    const secret = getSafeRandomNumber()
    addNewAccount({secret,contractAddress, accountSelectorEl})
    // addSecretLocalStorage({secret,address,contractAddress:contractAddress})
    // updateAccountSelector({accountSelectorEl,contractAddress: contractAddress, selectSecret: ethers.toBeHex(secret)})
}

function addNewAccount({secret,contractAddress, accountSelectorEl}) {
    const address  = hashAddress(secret)
    addSecretLocalStorage({secret,address,contractAddress:contractAddress})
    updateAccountSelector({accountSelectorEl,contractAddress: contractAddress, selectSecret: ethers.toBeHex(secret)})
}


/**
 * 
 * @param {{event: event, accountSelectorEl: Element}} param0 
 */
async function accountSelectorHandler({privTxsUl,pubTxsUl,event, accountSelectorEl, ultraAnonContract, deploymentBlock }) {
    const secret = accountSelectorEl.value
    const address = hashAddress(secret)
    updateBalances({secret, ultraAnonContract, deploymentBlock })
    updateTxList({txsUl:pubTxsUl,address,txType:"public",contractAddress:ultraAnonContract.target})
    updateTxList({txsUl:privTxsUl,address,txType:"private",contractAddress:ultraAnonContract.target})
    //updateTxList({tx}) //TODO
}

async function updateBalances({secret, ultraAnonContract, deploymentBlock }) {
    const address = ethers.zeroPadValue(ethers.toBeHex(hashAddress(secret)),20)
    const balance =  ultraAnonContract.balanceOf(address)
    const incomingBalance = ultraAnonContract.incomingBalance(address)
    const { currentNonce: currentShadowNonce, shadowBalance:prevShadowBalance } = await syncShadowBalance({ contract: ultraAnonContract, startBlock: deploymentBlock, secret: secret }); 
    const ticker =  ultraAnonContract.symbol()
    const actualBalance = (await incomingBalance) - prevShadowBalance
    setClass({className: "publiclyKnowBalance", value:ethers.formatUnits(await balance,18)})
    setClass({className: "actualBalance", value:ethers.formatUnits(actualBalance,18)})
    setClass({className: "ticker", value:await ticker})


    
}
/**
 * 
 * @param {{txsUl:element}} param0 
 */
function updateTxList({txsUl, address, txType,contractAddress}) {
    txsUl.innerHTML = ""
    const allSecrets = JSON.parse(localStorage.getItem(contractAddress))
    if (allSecrets) {
        const txsAllTypes = allSecrets[address].txs
        const txs = txsAllTypes ? txsAllTypes[txType] : false
        if (txs && txs.length) {
            for (const tx of txs) {
                const a = document.createElement("a")
                a.href = `https://sepolia.etherscan.io/tx/${tx}`
                a.innerText = `https://sepolia.etherscan.io/tx/${tx.slice(0,10) +"..."+ tx.slice(tx.length-10,tx.length)}`
                
                const li = document.createElement("li")
                li.classList.add("txs")
                li.appendChild(a)
                txsUl.appendChild(li)
            }
     
        }
    }
}


async function newTx({txhash, address, contractAddress,txType,txsUl}) {
    const allSecrets = JSON.parse(localStorage.getItem(contractAddress))
    if (txType !== "mint") {
        if("txs" in allSecrets[address] === false) {
            allSecrets[address].txs = {"private":[], "public":[], "mint":[]}
        }
        allSecrets[address].txs[txType].push(txhash)
        localStorage.setItem(contractAddress, JSON.stringify(allSecrets))
        updateTxList({txsUl,address,txType, contractAddress})

    }
    
    messageUi(`confirmed tx: https://sepolia.etherscan.io/tx/0x${txhash}`)
    
}



async function transferPubliclyHandler({allPublicTransfersUl,accountSelectorEl, recipientAddressInput, amountInput,ultraAnonContract, deploymentBlock}) {
    const amount = ethers.parseUnits(amountInput.value, 18)
    const to = ethers.getAddress(recipientAddressInput.value)
    const secret = accountSelectorEl.value  

    messageUi("creating proof")
    const tx = await publicTransfer({ amount: amount, to:to, ultraAnonContract:ultraAnonContract, secret:secret, deploymentBlock:deploymentBlock })
    await newTx({txsUl:allPublicTransfersUl, txType:"public",txhash: "0x"+tx.txn_hash, address: hashAddress(secret), contractAddress:ultraAnonContract.target})
    updateBalances({secret, ultraAnonContract, deploymentBlock })
}

async function transferPrivatelyHandler({allPrivateTransfersUl,accountSelectorEl, recipientAddressInput, amountInput,ultraAnonContract, deploymentBlock}) {
    const amount = ethers.parseUnits(amountInput.value, 18)
    const to = ethers.getAddress(recipientAddressInput.value)
    const secret = accountSelectorEl.value  

    messageUi("creating proof")
    const tx = await privateTransfer({ amount: amount, to:to, ultraAnonContract:ultraAnonContract, secret:secret, deploymentBlock:deploymentBlock })
    await newTx({txsUl:allPrivateTransfersUl, txType:"private",txhash: "0x"+tx.txn_hash, address: hashAddress(secret), contractAddress:ultraAnonContract.target})
    updateBalances({secret, ultraAnonContract, deploymentBlock })
}
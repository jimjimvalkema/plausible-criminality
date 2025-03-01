import { ethers } from "ethers"

import { hashAddress, getSafeRandomNumber } from "../scripts/hashor"
import {syncShadowBalance} from "../scripts/syncMaxing"
import { privateTransfer, publicTransfer } from "../scripts/transactionBuilder"

export function setEventHandlers({ultraAnonContract, deploymentBlock}) {
    const contractAddress = ultraAnonContract.target

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
    accountSelectorEl.addEventListener("change",async (event)=>accountSelectorHandler({event, accountSelectorEl, ultraAnonContract, deploymentBlock}))
    
    publicTransferBtn.addEventListener("click", async ()=>transferPubliclyHandler({accountSelectorEl, recipientAddressInput, amountInput, ultraAnonContract, deploymentBlock}))
    privateTransferBtn.addEventListener("click", async ()=>transferPrivatelyHandler({accountSelectorEl, recipientAddressInput, amountInput, ultraAnonContract, deploymentBlock}))

    updateAccountSelector({accountSelectorEl, contractAddress: contractAddress})

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
    allSecret[address] = ethers.toBeHex(secret)
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
        const firstSecret = allAddresses ? allSecrets[allAddresses[0]] : ""
        selectSecret = firstSecret 
    }

    // remove all option except the first one
    const optionIndexes = [...accountSelectorEl.options].map((v,i)=>i)
    optionIndexes.slice(1).forEach((index)=>accountSelectorEl.options.remove(index));
    for (const address in allSecrets) {
        const secret = allSecrets[address]
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

async function setPubliclyKnowBalance({address}) {
    "publiclyKnowBalance"
    
}


function generateAddressHandler({ultraAnonContract, accountSelectorEl}) {
    const contractAddress = ultraAnonContract.target
    const secret = getSafeRandomNumber()
    const address  = hashAddress(secret)
    addSecretLocalStorage({secret,address,contractAddress:contractAddress})
    updateAccountSelector({accountSelectorEl,contractAddress: contractAddress, selectSecret: ethers.toBeHex(secret)})
}

/**
 * 
 * @param {{event: event, accountSelectorEl: Element}} param0 
 */
async function accountSelectorHandler({event, accountSelectorEl, ultraAnonContract, deploymentBlock }) {
    const secret = accountSelectorEl.value
    updateBalances({secret, ultraAnonContract, deploymentBlock })
    updateTxList() //TODO
}

async function updateBalances({secret, ultraAnonContract, deploymentBlock }) {
    const address = ethers.toBeHex(hashAddress(secret))
    const balance =  ultraAnonContract.balanceOf(address)
    const { currentNonce: currentShadowNonce, shadowBalance:prevShadowBalance } = await syncShadowBalance({ contract: ultraAnonContract, startBlock: deploymentBlock, secret: secret }); 
    const ticker =  ultraAnonContract.symbol()
    const actualBalance = (await balance) - prevShadowBalance
    setClass({className: "publiclyKnowBalance", value:ethers.formatUnits(await balance,18)})
    setClass({className: "actualBalance", value:ethers.formatUnits(actualBalance,18)})
    setClass({className: "ticker", value:await ticker})
    
}

async function updateTxList() {


}

async function transferPubliclyHandler({accountSelectorEl, recipientAddressInput, amountInput,ultraAnonContract, deploymentBlock}) {
    const amount = ethers.parseUnits(amountInput.value, 18)
    const to = ethers.getAddress(recipientAddressInput.value)
    const secret = accountSelectorEl.value  

    const tx = await publicTransfer({ amount: amount, to:to, ultraAnonContract:ultraAnonContract, secret:secret, deploymentBlock:deploymentBlock })
    await tx.wait(1)
    updateBalances({secret, ultraAnonContract, deploymentBlock })
}

async function transferPrivatelyHandler({accountSelectorEl, recipientAddressInput, amountInput,ultraAnonContract, deploymentBlock}) {
    const amount = ethers.parseUnits(amountInput.value, 18)
    const to = ethers.getAddress(recipientAddressInput.value)
    const secret = accountSelectorEl.value  

    const tx = await privateTransfer({ amount: amount, to:to, ultraAnonContract:ultraAnonContract, secret:secret, deploymentBlock:deploymentBlock })
    await tx.wait(1)
    updateBalances({secret, ultraAnonContract, deploymentBlock })
}
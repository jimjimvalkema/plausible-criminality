import { ethers, wordlists } from "ethers";
import UltraAnonDeploymentArtifact from "../artifacts/contracts/UltraAnon.sol/UltraAnon.json"
import { syncInComingBalanceTree as syncIncomingBalanceTree, syncShadowTree, syncShadowBalance } from "../scripts/syncMaxing.js"
import { hashAddress, hashNullifierKey, hashNullifierValue } from "../scripts/hashor.js"
import { poseidon1, poseidon2 } from "poseidon-lite";
window.poseidon1 = poseidon1
window.poseidon2 = poseidon2
window.syncInComingBalanceTree = syncIncomingBalanceTree
window.syncShadowTree = syncShadowTree
window.syncShadowBalance = syncShadowBalance

window.hashAddress = hashAddress

const ultraAnonAbi = UltraAnonDeploymentArtifact.abi
const ultraAnonAddress = "0x28870cEE79a0430484BFB84A908Fb46aa686D1c5"//UltraAnonDeploymentArtifact.
const deploymentBlock = 7793115;
window.deploymentBlock = deploymentBlock
const CHAININFO = {
    chainId: "0xaa36a7",
    rpcUrls: ["https://1rpc.io/sepolia"],
    chainName: "Sepolia",
    nativeCurrency: {
        name: "ethereum",
        symbol: "ETH",
        decimals: 18
    },
    blockExplorerUrls: ["https://sepolia.etherscan.io/"]
}


async function switchNetwork(network, provider) {
    try {
        await provider.send("wallet_switchEthereumChain", [{ chainId: network.chainId }]);

    } catch (switchError) {
        window.switchError = switchError
        // This error code indicates that the chain has not been added to MetaMask.
        if (switchError.error && switchError.error.code === 4902) {
            try {
                await provider.send("wallet_addEthereumChain", [network]);

            } catch (addError) {
                // handle "add" error
            }
        }
        // handle other "switch" errors
    }
}

async function main() {
    const provider = new ethers.BrowserProvider(window.ethereum)
    await switchNetwork(CHAININFO, provider)
    const signer = await provider.getSigner();
    const ultraAnonContract = new ethers.Contract(ultraAnonAddress, ultraAnonAbi, signer)

    //debug shite
    window.ethers = ethers
    window.ultraAnonContract = ultraAnonContract
    window.provider = provider
    window.signer = signer
}

async function makePrivateTransfer({ amount, to, ultraAnonContract, secret }) {
    // @notice shadowBalanceTree, incomingBalanceTree are promises
    const shadowBalanceTree = syncShadowTree({ contract: ultraAnonContract, startBlock: deploymentBlock })
    const incomingBalanceTree = syncIncomingBalanceTree({ contract: ultraAnonContract, startBlock: deploymentBlock })
    window.incomingBalanceTree= incomingBalanceTree

    const ultraAnonSenderAddress = hashAddress(secret)

    //TODO sync correct nonce and shadow balance
    const shadowBalance = 0n;
    const shadowNonce = 2n;

    const nullifierValue = hashNullifierValue({balance:shadowBalance, nonce:shadowNonce, secret:secret});
    const nullifierKey = hashNullifierKey({nonce:shadowNonce, secret:secret});


    // TODO use noir to generate a real proof
    const proof = { proof: "0x00", publicInputs: [] }
    
    const contractCallInputs = {
        to: to,
        value: amount,
        nullifierValue: nullifierValue,
        nullifierKey: nullifierKey,
        shadowBalanceRoot: BigInt((await shadowBalanceTree).root),
        incomingBalanceRoot: BigInt((await incomingBalanceTree).root),
        proof: proof.proof
    }

    console.log({ contractCallInputs })
    ultraAnonContract.privateTransfer(
        contractCallInputs.to,
        contractCallInputs.value,
        contractCallInputs.nullifierValue,
        contractCallInputs.nullifierKey,
        contractCallInputs.shadowBalanceRoot,
        contractCallInputs.incomingBalanceRoot,
        contractCallInputs.proof
    )
}
window.makePrivateTransfer = makePrivateTransfer

await main()

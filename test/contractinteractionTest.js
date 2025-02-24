//hardhat
import "@nomicfoundation/hardhat-toolbox"
import { vars } from "hardhat/config.js"

//noir
import { UltraHonkBackend, UltraPlonkBackend } from '@aztec/bb.js';
import { Noir } from '@noir-lang/noir_js';
import circuit from '../circuits/test/target/test.json'  with { type: "json" }; //assert {type: 'json'};

// other
import { ethers } from 'ethers';
import deploymentArtifact from "../artifacts/contracts/verifier.sol/UltraVerifier.json"  with { type: "json" }; 
import os from "os"

const CONTRACT_ADDRESS = "0x965072C3516a7B9BC643094B3f4eC73E7Ac130Fc"

const PROVIDERURL = "https://1rpc.io/sepolia"
const provider = new ethers.JsonRpcProvider(PROVIDERURL)

const PRIVATE_KEY = vars.get("PRIVATE_KEY");
const wallet = new ethers.Wallet(PRIVATE_KEY, provider)

const contract = new ethers.Contract(CONTRACT_ADDRESS, deploymentArtifact.abi, wallet);

const noirCiruit = new Noir(circuit);
console.log(`generating proof with ${os.cpus().length} cores `)
const backend = new UltraPlonkBackend(circuit.bytecode,  { threads:  os.cpus().length });
const noirJsInputs = {x:1, y:2}
const { witness, returnValue } = await noirCiruit.execute(noirJsInputs);
const proof = await backend.generateProof(witness);
const verifiedByJs = await backend.verifyProof(proof);
console.log({verifiedByJs})

const verifiedByContract =  await contract.verify(proof.proof, proof.publicInputs)
console.log({verifiedByContract})
// idk its not stopping on its own prob wasm thing?
process.exit();

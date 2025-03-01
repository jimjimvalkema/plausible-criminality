# UltraAnon
A privacy token inspired by eip7503 that has maximum plausible deniability and a maximum anonymity set by joining public and private state.   
This is achieved by tracking the incoming balance and outgoing balance separately. Where the outgoing state is private and incoming is public. And then simply reusing the private transfer circuit to instead reveal the sender, in order to support public transfers.  
Enabled by a new [nullfier scheme](https://github.com/jimjimvalkema/scrollZkWormholes/blob/main/docs/notes.md#account-based-nullifiers). 
Try it out (single core only): https://ultaanon.jimjim.dev 
Run locally to enable multi core proving 

UltraAnon on sepolia: http://sepolia.etherscan.io/address/0xb200d5d4eaA13670553d6f0A66eE79E7F858C637



# install noir and backend
```shell
bbup -nv 1.0.0-beta.2
```

```shell
noirup -v 1.0.0-beta.2
```


# generate verifier contracts
<!-- //this should be a bash script lmao -->
```shell
# private transfer
cd circuits/privateTransfer/; 
nargo compile; 
bb write_vk -b ./target/privateTransfer.json;
bb contract;
cd ../..;

# public transfer
cd circuits/publicTransfer/; 
nargo compile; 
bb write_vk -b ./target/publicTransfer.json;
bb contract;
cd ../..;

# copy to contracts folder
cp circuits/privateTransfer/target/contract.sol contracts/PrivateTransferVerifier.sol
cp circuits/publicTransfer/target/contract.sol contracts/PublicTransferVerifier.sol


# rename contract in solidity
node scripts/replaceLine.js --file contracts/PrivateTransferVerifier.sol --remove "contract UltraVerifier is BaseUltraVerifier {" --replace "contract PrivateTransferVerifier is BaseUltraVerifier {"
node scripts/replaceLine.js --file contracts/PublicTransferVerifier.sol --remove "contract UltraVerifier is BaseUltraVerifier {" --replace "contract PublicTransferVerifier is BaseUltraVerifier {"
```

# deploy
```shell
rm -fr ignition/deployments;
yarn hardhat run scripts/deploy.js --network sepolia;
```

# verify etherscan
```shell
yarn hardhat ignition verify chain-11155111 --include-unrelated-contracts
```

<!-- try out contract interaction 
```shell
yarn hardhat run test/contractinteractionTest.js 
``` -->
# Relay

This is a small webserver that executes smart contract calls for others. This is important to preserve the privacy of UltraAnon users. Send arguments for either `UltraAnon.publicTransfer` or `UltraAnon.privateTransfer` to the endpoints `/public_transfer` or `/private_transfer`.

# Running

By default it will run locally at port 8000. Requires env vars `PROVIDER_URL`, `CONTRACT_ADDRESS` (ultraAnon contract address) and `PRIVATE_KEY`.

Run with `cargo run` (dev) or `cargo run --release` (prod).

If you run into issues after getting it to work once or twice it's likely your rpc.
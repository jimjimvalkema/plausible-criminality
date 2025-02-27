All my friends know am not a terrorist :) I love my friends!!!




<!-- 
```shell
nargo init --name test
``` -->
install noir and backend
```shell
bbup -nv 1.0.0-beta.2
```

```shell
noirup -v 1.0.0-beta.2
```


generate verifier contracts
//this should be a bash script lmao
```shell
# private transfer
cd circuits/privateTransfer/; 
nargo compile; 
bb write_vk -b ./target/PrivateTransfer.json;
bb contract;
cd ../..;

# public transfer
cd circuits/publicTransfer/; 
nargo compile; 
bb write_vk -b ./target/PublicTransfer.json;
bb contract;
cd ../..;

# copy to contracts folder
cp circuits/privateTransfer/target/contract.sol contracts/PrivateTransferVerifier.sol
cp circuits/publicTransfer/target/contract.sol contracts/PublicTransferVerifier.sol


# rename contract in solidity
node scripts/replaceLine.js --file contracts/PrivateTransferVerifier.sol --remove "contract UltraVerifier is BaseUltraVerifier {" --replace "contract PrivateTransferVerifier is BaseUltraVerifier {"
node scripts/replaceLine.js --file contracts/PublicTransferVerifier.sol --remove "contract UltraVerifier is BaseUltraVerifier {" --replace "contract PublicTransferVerifier is BaseUltraVerifier {"
```

copy to contracts
```shell
cp circuits/test/target/contract.sol contracts/verifier.sol
```


deploy
```shell
yarn hardhat run scripts/deploy.js --network sepolia;
```

verify etherscan
```shell
yarn hardhat ignition verify chain-11155111 --include-unrelated-contracts
```

<!-- try out contract interaction 
```shell
yarn hardhat run test/contractinteractionTest.js 
``` -->


UltraAnon test (doesn't verifying proofs): https://sepolia.etherscan.io/address/0xff18887aa3111f19f6582c32d667eb5cd2ec0214#code
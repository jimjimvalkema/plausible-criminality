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


generate verifier contract
```shell
bb write_vk -b ./target/test.json;
bb contract

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


UltraAnon test (doesn't verifying proofs): https://sepolia.etherscan.io/address/0xA38db958dcb4Dc0246BBdD6010bb69dCD005c9f5#code
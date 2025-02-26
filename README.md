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
yarn hardhat ignition deploy ./ignition/modules/Verifier.cjs --verify  --network sepolia;
```

verify etherscan
```shell
yarn hardhat ignition verify chain-11155111 --include-unrelated-contracts
```

try out contract interaction 
```shell
yarn hardhat run test/contractinteractionTest.js 
```


UltraAnon test as erc20 that has a incoming balance tree: https://sepolia.etherscan.io/address/0xAc44dD10D555F1da3F955d62F67Eec9C4d37f0a8#code
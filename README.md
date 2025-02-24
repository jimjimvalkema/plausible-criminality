# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

```shell
yarn hardhat ignition verify chain-11155111 --include-unrelated-contracts
```


```shell
bbup -nv 1.0.0-beta.2
```

```shell
noirup -v 1.0.0-beta.2
```


```shell
nargo init --name test
```

```shell
bb write_vk -b ./target/test.json;
bb contract

```

```shell
cp circuits/test/target/contract.sol contracts/verifier.sol
```
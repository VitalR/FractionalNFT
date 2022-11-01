## Fractional NFT Project

### About this repo
It is a [Foundry](https://book.getfoundry.sh/) repo with Solidity tests powered by the [ds-test library](https://github.com/dapphub/ds-test/).

### Setup

1. `git clone repo`
2. Ensure you have installed Rust and Cargo: [Install Rust](https://www.rust-lang.org/tools/install)
3. Install Foundry: [instructions](https://book.getfoundry.sh/getting-started/installation)
4. Run tests: `forge test`


### Pre-deployment

Copy the .env.example file to .env and update the values:

```
PRIVATE_KEY=''
ETHERSCAN_API_KEY=''
INFURA_API_KEY=''
```

### Deployment & Verification on Goerli

NFTCollection:
```
./script/1_deploy.sh
```

TokenVault:

```
./script/2_deploy.sh
```


### Example of Foundry/Forge commands
```
forge tree
forge build
forge test -vvv
forge test --match-contract <ContractTest> --match-test <testName> -vvvvv
```
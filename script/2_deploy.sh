#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

# deploy
forge create ./src/TokenVault.sol:TokenVault -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY}

# deploy & verify
# forge create --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} ./src/TokenVault.sol:TokenVault\
#     --constructor-args ${CURATOR_ADDRESS} "0" "TOKEN_NAME" "TOKEN_SYMBOL" "DEFAULT_TOKEN_URI"\
#     --private-key ${PRIVATE_KEY} \
#     --etherscan-api-key ${ETHERSCAN_API_KEY} \
#     --verify

 
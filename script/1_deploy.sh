#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

# forge create ./src/NFTCollection.sol:NFTCollection -i --rpc-url 'https://eth-goerli.g.alchemy.com/v2/'${ALCHEMY_API_KEY} --private-key ${PRIVATE_KEY}

# deploy
forge create ./src/NFTCollection.sol:NFTCollection -i --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} --private-key ${PRIVATE_KEY}

# deploy & verify
# forge create --rpc-url 'https://goerli.infura.io/v3/'${INFURA_API_KEY} \
#     --private-key ${PRIVATE_KEY} ./src/NFTCollection.sol:NFTCollection\
#     --etherscan-api-key ${ETHERSCAN_API_KEY} \
#     --verify
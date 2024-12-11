#!/bin/bash

echo ""
echo "##########################################"
echo "# Create, Delete, Mint with Tokenfactory #"
echo "##########################################"
echo ""

BINARY=vectord
CHAIN_DIR=$(pwd)/data
TOKEN_DENOM=utoken$RANDOM
MINT_AMOUNT=1000000
CHAIN_ID=test-1

GAS=2000000
FEES=1000000uvctr

# Get wallet addresses from the initialized test framework
WALLET_1=$($BINARY keys show val1 -a --keyring-backend test --home $CHAIN_DIR/test-1)
WALLET_2=$($BINARY keys show val2 -a --keyring-backend test --home $CHAIN_DIR/test-2)

echo "Creating token denom $TOKEN_DENOM with $WALLET_1 on chain test-1"
TX_HASH=$($BINARY tx tokenfactory create-denom $TOKEN_DENOM --from $WALLET_1 --home $CHAIN_DIR/test-1 --chain-id $CHAIN_ID --node tcp://localhost:16657 --gas "$GAS" --fees "$FEES" --keyring-backend test -o json -y | jq -r '.txhash')
sleep 3

echo "Querying tx $TX_HASH"
$BINARY query tx $TX_HASH -o json  --home $CHAIN_DIR/test-1 --node tcp://localhost:16657

CREATED_RES_DENOM=$($BINARY query tx $TX_HASH -o json  --home $CHAIN_DIR/test-1 --node tcp://localhost:16657 | jq -r '.events[] | select(.type=="create_denom") | .attributes[] | select(.key=="new_token_denom") | .value')

if [ "$CREATED_RES_DENOM" != "factory/$WALLET_1/$TOKEN_DENOM" ]; then
    echo "ERROR: Tokenfactory creating denom error. Expected result 'factory/$WALLET_1/$TOKEN_DENOM', got '$CREATED_RES_DENOM'"
    exit 1
fi



#!/bin/bash

export KEY="acc0"
export KEY2="acc1"

export CHAIN_ID=${CHAIN_ID:-"localchain-1"}
export MONIKER="localvalidator"
export KEYALGO="secp256k1"
export KEYRING=${KEYRING:-"test"}
export HOME_DIR=$(eval echo "${HOME_DIR:-"mytestnet"}")
export BINARY=${BINARY:-vectord}
export DENOM=${DENOM:-uvctr}

export CLEAN=${CLEAN:-"false"}
export RPC=${RPC:-"26657"}
export REST=${REST:-"1317"}
export PROFF=${PROFF:-"6060"}
export P2P=${P2P:-"26656"}
export GRPC=${GRPC:-"9090"}
export GRPC_WEB=${GRPC_WEB:-"9091"}
export PROFF_LADDER=${PROFF_LADDER:-"6060"}
export ROSETTA=${ROSETTA:-"8080"}
export BLOCK_TIME=${BLOCK_TIME:-"1s"}

# Ensure binary exists
if [ -z `which $BINARY` ]; then
  make install
  if [ -z `which $BINARY` ]; then
    echo "Ensure $BINARY is installed and in your PATH"
    exit 1
  fi
fi

command -v $BINARY > /dev/null 2>&1 || { echo >&2 "$BINARY command not found. Ensure this is setup / properly installed in your GOPATH (make install)."; exit 1; }
command -v jq > /dev/null 2>&1 || { echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"; exit 1; }

set_config() {
  $BINARY config set client chain-id $CHAIN_ID --home $HOME_DIR
  $BINARY config set client keyring-backend $KEYRING --home $HOME_DIR
}

from_scratch() {
  echo "Creating new chain from scratch..."
  
  # remove existing daemon files
  if [ ${#HOME_DIR} -le 2 ]; then
    echo "HOME_DIR must be more than 2 characters long"
    return
  fi
  rm -rf $HOME_DIR
  
  # Create chain
  $BINARY init $MONIKER --chain-id $CHAIN_ID --default-denom $DENOM --home $HOME_DIR

  # Add keys
  echo "decorate bright ozone fork gallery riot bus exhaust worth way bone indoor calm squirrel merry zero scheme cotton until shop any excess stage laundry" | \
    $BINARY keys add $KEY --keyring-backend $KEYRING --algo $KEYALGO --recover --home $HOME_DIR
  
  echo "wealth flavor believe regret funny network recall kiss grape useless pepper cram hint member few certain unveil rather brick bargain curious require crowd raise" | \
    $BINARY keys add $KEY2 --keyring-backend $KEYRING --algo $KEYALGO --recover --home $HOME_DIR

  # Update genesis
  update_test_genesis () {
    cat $HOME_DIR/config/genesis.json | jq "$1" > $HOME_DIR/config/tmp_genesis.json && mv $HOME_DIR/config/tmp_genesis.json $HOME_DIR/config/genesis.json
  }

  # Block
  update_test_genesis '.consensus_params["block"]["max_gas"]="100000000"'

  # Gov
  update_test_genesis `printf '.app_state["gov"]["params"]["min_deposit"]=[{"denom":"%s","amount":"1000000"}]' $DENOM`
  update_test_genesis '.app_state["gov"]["params"]["voting_period"]="30s"'
  update_test_genesis '.app_state["gov"]["params"]["expedited_voting_period"]="15s"'

  # Staking
  update_test_genesis `printf '.app_state["staking"]["params"]["bond_denom"]="%s"' $DENOM`
  update_test_genesis '.app_state["staking"]["params"]["min_commission_rate"]="0.050000000000000000"'

  # Mint
  update_test_genesis `printf '.app_state["mint"]["params"]["mint_denom"]="%s"' $DENOM`

  # Crisis
  update_test_genesis `printf '.app_state["crisis"]["constant_fee"]={"denom":"%s","amount":"1000"}' $DENOM`

  # Custom modules
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_fee"]=[]'
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_gas_consume"]=100000'

  # Add genesis accounts
  $BINARY genesis add-genesis-account $KEY 10000000000000$DENOM --keyring-backend $KEYRING --home $HOME_DIR
  $BINARY genesis add-genesis-account $KEY2 10000000000000$DENOM --keyring-backend $KEYRING --home $HOME_DIR

  # Generate genesis tx
  $BINARY genesis gentx $KEY 1000000000000$DENOM --keyring-backend $KEYRING --chain-id $CHAIN_ID --home $HOME_DIR

  # Collect genesis tx
  $BINARY genesis collect-gentxs --home $HOME_DIR

  # Validate genesis
  $BINARY genesis validate-genesis --home $HOME_DIR
}

# Initialize chain if CLEAN is true or if genesis doesn't exist
if [ "$CLEAN" = "true" ] || [ ! -f "$HOME_DIR/config/genesis.json" ]; then
  echo "Initializing chain..."
  from_scratch
  set_config
fi

echo "Starting node..."

# Update configs
sed -i.bak -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${REST}\"%" $HOME_DIR/config/app.toml
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${GRPC}\"%" $HOME_DIR/config/app.toml
sed -i.bak -e "s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${GRPC_WEB}\"%" $HOME_DIR/config/app.toml
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:${RPC}\"%" $HOME_DIR/config/client.toml
sed -i.bak -e "s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://0.0.0.0:${RPC}\"%" $HOME_DIR/config/config.toml
sed -i.bak -e "s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${P2P}\"%" $HOME_DIR/config/config.toml
sed -i.bak -e "s%^timeout_commit = \"5s\"%timeout_commit = \"${BLOCK_TIME}\"%" $HOME_DIR/config/config.toml
sed -i.bak -e 's%^cors_allowed_origins = \[\]%cors_allowed_origins = \["*"\]%' $HOME_DIR/config/config.toml

# Start the node
$BINARY start --home $HOME_DIR \
  --pruning=nothing \
  --minimum-gas-prices=0$DENOM \
  --rpc.laddr="tcp://0.0.0.0:$RPC"
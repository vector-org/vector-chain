#!/bin/bash

set -eu

export KEY="acc0"
export KEY2="acc1"

export CHAIN_ID=${CHAIN_ID:-"scalar_1337-2"}
export MONIKER="localvalidator"
export KEYALGO="eth_secp256k1"
export KEYRING=${KEYRING:-"test"}
export CHAIN_DIR=$(eval echo "${CHAIN_DIR:-"./chain_data"}")
export BINARY=${BINARY:-"./build/vectord"}
export DENOM=${DENOM:-uvctr}

export CLEAN=${CLEAN:-"true"}
export RPC=${RPC:-"26657"}
export REST=${REST:-"1317"}
export PROFF=${PROFF:-"6060"}
export P2P=${P2P:-"26656"}
export GRPC=${GRPC:-"9090"}
export GRPC_WEB=${GRPC_WEB:-"9091"}
export ROSETTA=${ROSETTA:-"8080"}
export BLOCK_TIME=${BLOCK_TIME:-"5s"}


# Check if binary exists - handle relative paths properly
if [[ "$BINARY" == ./* ]] || [[ "$BINARY" == /* ]]; then
  # It's a relative or absolute path, check if file exists
  if [ ! -f "$BINARY" ]; then
    echo "Building binary..."
    make install
    if [ ! -f "$BINARY" ]; then
      echo "Error: Binary $BINARY not found. Please build it first with 'make install'"
      exit 1
    fi
  fi
else
  # It's a command name, check if it's in PATH
  if ! command -v $BINARY > /dev/null 2>&1; then
    echo "Building binary..."
    make install
    if ! command -v $BINARY > /dev/null 2>&1; then
      echo "Error: $BINARY command not found. Ensure this is setup / properly installed in your GOPATH (make install)."
      exit 1
    fi
  fi
fi

command -v jq > /dev/null 2>&1 || { echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"; exit 1; }

set_config() {
  $BINARY config set client chain-id $CHAIN_ID
  $BINARY config set client keyring-backend $KEYRING
}
set_config


from_scratch () {
  # Fresh install on current branch
  make install

  # remove existing daemon files.
  if [ ${#CHAIN_DIR} -le 2 ]; then
      echo "CHAIN_DIR must be more than 2 characters long"
      return
  fi
  rm -rf $CHAIN_DIR && echo "Removed $CHAIN_DIR"

  # reset values if not set already after whipe
  set_config

  add_key() {
    key=$1
    mnemonic=$2
    echo $mnemonic | $BINARY keys add $key --keyring-backend $KEYRING --algo $KEYALGO --home $CHAIN_DIR --recover
  }

  # vector140fehngcrxvhdt84x729p3f0qmkmea8nt2uzux
  add_key $KEY "decorate bright ozone fork gallery riot bus exhaust worth way bone indoor calm squirrel merry zero scheme cotton until shop any excess stage laundry"
  
  # vector1r6yue0vuyj9m7xw78npspt9drq2tmtvg8h6r0d
  add_key $KEY2 "wealth flavor believe regret funny network recall kiss grape useless pepper cram hint member few certain unveil rather brick bargain curious require crowd raise"

  $BINARY init $MONIKER --chain-id $CHAIN_ID --default-denom $DENOM --home $CHAIN_DIR

  update_test_genesis () {
    cat $CHAIN_DIR/config/genesis.json | jq "$1" > $CHAIN_DIR/config/tmp_genesis.json && mv $CHAIN_DIR/config/tmp_genesis.json $CHAIN_DIR/config/genesis.json
  }

  # === CORE MODULES ===

  # Block
  update_test_genesis '.consensus_params["block"]["max_gas"]="100000000"'

  # Gov
  update_test_genesis `printf '.app_state["gov"]["params"]["min_deposit"]=[{"denom":"%s","amount":"1000000"}]' $DENOM`
  update_test_genesis '.app_state["gov"]["params"]["voting_period"]="420s"'
  update_test_genesis '.app_state["gov"]["params"]["expedited_voting_period"]="15s"'

  update_test_genesis `printf '.app_state["evm"]["params"]["evm_denom"]="%s"' $DENOM`
  update_test_genesis '.app_state["evm"]["params"]["chain_config"]["chain_id"]="1337"'
  update_test_genesis '.app_state["evm"]["params"]["chain_config"]["denom"]="'$DENOM'"'
  update_test_genesis '.app_state["evm"]["params"]["chain_config"]["decimals"]="18"'

  # EVM
  update_test_genesis '.app_state["evm"]["params"]["active_static_precompiles"]=["0x0000000000000000000000000000000000000100","0x0000000000000000000000000000000000000400","0x0000000000000000000000000000000000000800","0x0000000000000000000000000000000000000801","0x0000000000000000000000000000000000000802","0x0000000000000000000000000000000000000803","0x0000000000000000000000000000000000000804","0x0000000000000000000000000000000000000805"]'
  update_test_genesis '.app_state["erc20"]["params"]["native_precompiles"]=["0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"]' # https://eips.ethereum.org/EIPS/eip-7528
  update_test_genesis `printf '.app_state["erc20"]["token_pairs"]=[{contract_owner:1,erc20_address:"0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",denom:"%s",enabled:true}]' $DENOM`
  
  update_test_genesis '.app_state["feemarket"]["params"]["no_base_fee"]=false'
  update_test_genesis '.app_state["feemarket"]["params"]["base_fee_change_denominator"]=8'
  update_test_genesis '.app_state["feemarket"]["params"]["elasticity_multiplier"]=2'
  update_test_genesis '.app_state["feemarket"]["params"]["enable_height"]="0"'
  
  update_test_genesis '.app_state["feemarket"]["params"]["base_fee"]="0.010000000000000000"'
  update_test_genesis '.app_state["feemarket"]["params"]["min_gas_price"]="0.010000000000000000"'
  update_test_genesis '.app_state["feemarket"]["params"]["min_gas_multiplier"]="0.500000000000000000"'

  # Disable IBC transfer
  update_test_genesis '.app_state["transfer"]["params"]["send_enabled"]=false'
  update_test_genesis '.app_state["transfer"]["params"]["receive_enabled"]=false'

  # Disable IBC modules
  update_test_genesis '.app_state["interchainaccounts"]["controller_genesis_state"]["params"]["controller_enabled"]=false'
  update_test_genesis '.app_state["interchainaccounts"]["host_genesis_state"]["params"]["host_enabled"]=false'
  update_test_genesis '.app_state["interchainaccounts"]["host_genesis_state"]["params"]["allow_messages"]=[]'
  
  # staking
  update_test_genesis `printf '.app_state["staking"]["params"]["bond_denom"]="%s"' $DENOM`
  update_test_genesis '.app_state["staking"]["params"]["min_commission_rate"]="0.050000000000000000"'

  # mint
  update_test_genesis `printf '.app_state["mint"]["params"]["mint_denom"]="%s"' $DENOM`

  # mint parameters
  update_test_genesis '.app_state["mint"]["params"]["inflation_rate_change"]="0.000000000000000000"'
  update_test_genesis '.app_state["mint"]["params"]["inflation_max"]="0.000000000000000000"'
  update_test_genesis '.app_state["mint"]["params"]["inflation_min"]="0.000000000000000000"'
  update_test_genesis '.app_state["mint"]["params"]["goal_bonded"]="0.670000000000000000"'
  update_test_genesis '.app_state["mint"]["params"]["blocks_per_year"]="6311520"'
  
  # crisis
  update_test_genesis `printf '.app_state["crisis"]["constant_fee"]={"denom":"%s","amount":"1000"}' $DENOM`

  ## abci
  update_test_genesis '.consensus["params"]["abci"]["vote_extensions_enable_height"]="1"'

  # === CUSTOM MODULES ===
  # tokenfactory
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_fee"]=[]'
  update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_gas_consume"]=100000'


  # BASE_GENESIS_ALLOCATIONS="100000000000000000000000000$DENOM,100000000test"

  # # Allocate genesis accounts
  # $BINARY genesis add-genesis-account $KEY $BASE_GENESIS_ALLOCATIONS --keyring-backend $KEYRING --home $CHAIN_DIR --append
  # $BINARY genesis add-genesis-account $KEY2 $BASE_GENESIS_ALLOCATIONS --keyring-backend $KEYRING --home $CHAIN_DIR --append

  # # Sign genesis transaction
  # $BINARY genesis gentx $KEY 1000000000000000000000$DENOM --gas-prices 0.1${DENOM} --keyring-backend $KEYRING --chain-id $CHAIN_ID --home $CHAIN_DIR

  # $BINARY genesis collect-gentxs --home $CHAIN_DIR

  # $BINARY genesis validate-genesis --home $CHAIN_DIR
  # err=$?
  # if [ $err -ne 0 ]; then
  #   echo "Failed to validate genesis"
  #   return
  # fi

  echo "Created genesis"
}

# check if CLEAN is not set to false
if [ "$CLEAN" != "false" ]; then
  echo "Starting from a clean state"
  from_scratch
fi

echo "Starting node..."

# Opens the RPC endpoint to outside connections
sed -i -e 's/laddr = "tcp:\/\/127.0.0.1:26657"/c\laddr = "tcp:\/\/0.0.0.0:'$RPC'"/g' $CHAIN_DIR/config/config.toml
sed -i -e 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $CHAIN_DIR/config/config.toml

# REST endpoint
sed -i -e 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:'$REST'"/g' $CHAIN_DIR/config/app.toml
sed -i -e 's/enable = false/enable = true/g' $CHAIN_DIR/config/app.toml
sed -i -e 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' $CHAIN_DIR/config/app.toml

# JSON-RPC endpoint
sed -i -e 's/address = "127.0.0.1:8545"/address = "0.0.0.0:8545"/g' $CHAIN_DIR/config/app.toml
sed -i -e 's/ws-address = "127.0.0.1:8546"/ws-address = "0.0.0.0:8546"/g' $CHAIN_DIR/config/app.toml
sed -i -e 's/api = "eth,net,web3"/api = "eth,txpool,personal,net,debug,web3"/g' $CHAIN_DIR/config/app.toml

# peer exchange
sed -i -e 's/pprof_laddr = "localhost:6060"/pprof_laddr = "localhost:'$PROFF'"/g' $CHAIN_DIR/config/config.toml
sed -i -e 's/laddr = "tcp:\/\/0.0.0.0:26656"/laddr = "tcp:\/\/0.0.0.0:'$P2P'"/g' $CHAIN_DIR/config/config.toml

# GRPC
sed -i -e 's/address = "localhost:9090"/address = "0.0.0.0:'$GRPC'"/g' $CHAIN_DIR/config/app.toml
sed -i -e 's/address = "localhost:9091"/address = "0.0.0.0:'$GRPC_WEB'"/g' $CHAIN_DIR/config/app.toml

# Rosetta Api
sed -i -e 's/address = ":8080"/address = "0.0.0.0:'$ROSETTA'"/g' $CHAIN_DIR/config/app.toml

# Faster blocks
sed -i -e 's/timeout_commit = "5s"/timeout_commit = "'$BLOCK_TIME'"/g' $CHAIN_DIR/config/config.toml

# Set minimum gas prices
sed -i -e 's/minimum-gas-prices = ".*"/minimum-gas-prices = "0.1'$DENOM'"/g' $CHAIN_DIR/config/app.toml

# $BINARY start --pruning=nothing  --minimum-gas-prices=0.1$DENOM --rpc.laddr="tcp://0.0.0.0:$RPC" --home $CHAIN_DIR --json-rpc.api=eth,txpool,personal,net,debug,web3 --chain-id="$CHAIN_ID"

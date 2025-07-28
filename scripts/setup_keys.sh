#!/bin/bash
# Setup keys and create gentx for vectorchain
# This script assumes ~/.vectorchain directory exists with genesis.json
# It will add keys, genesis accounts, and create/collect gentx
#
# Examples:
# sh scripts/setup_keys.sh
# CHAIN_ID="scalar_1337-2" sh scripts/setup_keys.sh

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

# Check if jq is installed
command -v jq > /dev/null 2>&1 || { echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"; exit 1; }

# Set client configuration
$BINARY config set client chain-id $CHAIN_ID
$BINARY config set client keyring-backend $KEYRING

# Check if the directory exists
if [ ! -d "$CHAIN_DIR" ]; then
  echo "Error: Directory $CHAIN_DIR does not exist. Please ensure vectorchain is initialized."
  exit 1
fi

# Check if genesis file exists
if [ ! -f "$CHAIN_DIR/config/genesis.json" ]; then
  echo "Error: Genesis file not found at $CHAIN_DIR/config/genesis.json. Please ensure the directory is properly configured."
  exit 1
fi

echo "Setting up keys and gentx for vectorchain..."
echo "Using directory: $CHAIN_DIR"
echo "Chain ID: $CHAIN_ID"

# Function to check if a key exists
key_exists() {
  local key=$1
  $BINARY keys show $key --keyring-backend $KEYRING --home $CHAIN_DIR >/dev/null 2>&1
}

# Function to add a key with recovery phrase, skip if exists
add_key() {
  local key=$1
  local mnemonic=$2
  
  if key_exists $key; then
    echo "Key $key already exists, skipping..."
  else
    echo "Adding key: $key"
    echo $mnemonic | $BINARY keys add $key --keyring-backend $KEYRING --algo $KEYALGO --home $CHAIN_DIR --recover
  fi
}

# Add keys with predefined mnemonics
# cosmos140fehngcrxvhdt84x729p3f0qmkmea8nt2uzux
add_key $KEY "decorate bright ozone fork gallery riot bus exhaust worth way bone indoor calm squirrel merry zero scheme cotton until shop any excess stage laundry"

# cosmos1r6yue0vuyj9m7xw78npspt9drq2tmtvg8h6r0d  
add_key $KEY2 "wealth flavor believe regret funny network recall kiss grape useless pepper cram hint member few certain unveil rather brick bargain curious require crowd raise"

# Base allocation amounts
BASE_GENESIS_ALLOCATIONS="100000000000000000000000000$DENOM,100000000test"

# Add genesis accounts to the existing genesis
echo "Adding genesis accounts..."
$BINARY genesis add-genesis-account $KEY $BASE_GENESIS_ALLOCATIONS --keyring-backend $KEYRING --home $CHAIN_DIR --append
$BINARY genesis add-genesis-account $KEY2 $BASE_GENESIS_ALLOCATIONS --keyring-backend $KEYRING --home $CHAIN_DIR --append

# Create genesis transaction
echo "Creating genesis transaction..."
$BINARY genesis gentx $KEY 1000000000000000000000$DENOM --gas-prices 1${DENOM} --keyring-backend $KEYRING --chain-id $CHAIN_ID --home $CHAIN_DIR

# Collect genesis transactions
echo "Collecting genesis transactions..."
$BINARY genesis collect-gentxs --home $CHAIN_DIR

# Validate the genesis
echo "Validating genesis..."
$BINARY genesis validate-genesis --home $CHAIN_DIR
err=$?
if [ $err -ne 0 ]; then
  echo "Failed to validate genesis"
  exit 1
fi

echo "Keys and gentx setup completed successfully!"
echo "Key 1 ($KEY): cosmos140fehngcrxvhdt84x729p3f0qmkmea8nt2uzux"
echo "Key 2 ($KEY2): cosmos1r6yue0vuyj9m7xw78npspt9drq2tmtvg8h6r0d"
#!/bin/bash
# Start the vectorchain node using existing configuration
# This script assumes ~/.vectorchain is already properly configured
#
# Examples:
# sh scripts/start_node.sh
# CHAIN_ID="scalar_1337-2" sh scripts/start_node.sh

set -eu

export CHAIN_ID=${CHAIN_ID:-"scalar_1337-2"}
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

# Set client configuration
$BINARY config set client chain-id $CHAIN_ID
$BINARY config set client keyring-backend $KEYRING

# Check if the directory exists
if [ ! -d "$CHAIN_DIR" ]; then
  echo "Error: Directory $CHAIN_DIR does not exist. Please run the setup script first."
  exit 1
fi

# Check if genesis file exists
if [ ! -f "$CHAIN_DIR/config/genesis.json" ]; then
  echo "Error: Genesis file not found at $CHAIN_DIR/config/genesis.json. Please ensure the directory is properly configured."
  exit 1
fi

echo "Starting vectorchain node..."
echo "Using directory: $CHAIN_DIR"
echo "Chain ID: $CHAIN_ID"

# Start the node with existing configuration
$BINARY start --pruning=nothing --home $CHAIN_DIR --json-rpc.api=eth,txpool,personal,net,debug,web3 --chain-id="$CHAIN_ID"
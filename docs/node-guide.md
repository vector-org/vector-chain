# Vector Chain Node Guide

This guide walks you through the process of joining the `vector-chain` network. Whether you aim to participate as a Validator, run an Archive node for historical data, or operate a Public node to support the network, the following steps will guide you through installation, configuration, and startup.

---

## Table of Contents

1. [Install Binary](#1-install-binary)
2. [Initialize Node](#2-initialize-node)
3. [Configure Node Type](#3-configure-node-type)
   - [Configure as a Validator](#configure-as-a-validator)
   - [Configure as an Archive Node](#configure-as-an-archive-node)
   - [Configure as a Public Node](#configure-as-a-public-node)
4. [Join the Network](#5-join-the-network)

---

## 1. Install Binary

Set environment variables to simplify your workflow. Adjust values as needed:

```bash
# Home directory for the node
export VECTOR_HOME=$HOME/.vectord

# Chain ID (match the chain you want to join)
export VECTOR_CHAIN_ID=vector-1

# Git tag for the code version you want to run
export VECTOR_TAG=v1.0.0
```

Install prerequisites (Go, Git, etc.) as needed, then:

```bash
# Enter the home directory
cd $HOME

# Clone the official vector-chain repository
git clone git@github.com:vector-org/vector-chain.git

# Enter the repository directory
cd vector-chain

# Checkout the correct version
git checkout $VECTOR_TAG

# Build and install the vector-chain binary
make install
```

Verify the installation:

```bash
vectord version
```

You should see a version matching $VECTOR_TAG.

---

## 2. Initialize Node

Initialize your node configuration:

```bash
vectord init $VECTOR_MONIKER --home $VECTOR_HOME
```

This creates configuration files in $VECTOR_HOME/config.

Check that the directories exist:

```bash
ls $VECTOR_HOME
```

Backup node_key.json and priv_validator_key.json.

---

## 3. Configure Node Type

All configuration files are located in $VECTOR_HOME/config/. Adjust them according to the node type you are running.

### Configure as a Validator

Validators secure the network by producing blocks. Set the following environment variables:

```bash
export VECTOR_COMMISSION_MAX_CHANGE_RATE=0.01
export VECTOR_COMMISSION_MAX_RATE=0.20
export VECTOR_COMMISSION_RATE=0.05
export VECTOR_DETAILS="Your validator details"
export VECTOR_IDENTITY="your_keybase_id"
export VECTOR_KEY_NAME="myvalidatorkey"
export VECTOR_MIN_SELF_DELEGATION=1
export VECTOR_MONIKER="MyValidatorMoniker"
export VECTOR_SECURITY_CONTACT="security@example.com"
export VECTOR_WEBSITE="https://example.com"
```

You need a key to sign blocks and transactions:

```bash
vectord keys add $VECTOR_KEY_NAME --home $VECTOR_HOME
```

Use --recover if you have an existing mnemonic. Confirm your key:

```bash
vectord keys list --home $VECTOR_HOME
```

Backup your mnemonic.

To create your validator after you have funds and are synced:

```bash
vectord tx staking create-validator \
--from $VECTOR_KEY_NAME \
--amount 1000000uvctr \
--commission-max-change-rate $VECTOR_COMMISSION_MAX_CHANGE_RATE \
--commission-max-rate $VECTOR_COMMISSION_MAX_RATE \
--commission-rate $VECTOR_COMMISSION_RATE \
--details "$VECTOR_DETAILS" \
--identity $VECTOR_IDENTITY \
--min-self-delegation $VECTOR_MIN_SELF_DELEGATION \
--moniker $VECTOR_MONIKER \
--website $VECTOR_WEBSITE \
--security-contact $VECTOR_SECURITY_CONTACT \
--chain-id $VECTOR_CHAIN_ID \
--gas-adjustment 1.2 \
--home $VECTOR_HOME
```

### Configure as an Archive Node

Archive nodes store full chain history. In $VECTOR_HOME/config/app.toml, set:

```toml
pruning = "nothing"
```

Ensure sufficient disk space and resources as the chain grows.

### Configure as a Public Node

Public nodes provide RPC, API, and gRPC endpoints. If running a public node, expose these services securely by opening appropriate ports, using rate limits, reverse proxies, and firewalls. Adjust pruning to manage disk usage as needed.

---

## 4. Join the Network

To participate, your node must be synchronized with the latest block height. There are three primary methods:

- **Sync from Genesis**: Processes all blocks from the start. Suitable for archive nodes due to time and resource requirements.
- **Use a Snapshot**: Obtain a snapshot from a trusted validator or community member to skip processing historical data.
- **State Sync**: Quickly fetch the current network state from peers, suitable for validators and public nodes that need rapid startup.

Choose the method that best fits your operational goals, hardware constraints, and bandwidth. Most validators and public nodes find snapshots or state sync preferable for faster, more efficient network integration.

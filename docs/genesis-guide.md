# Genesis Guide

Welcome to the **Vector Chain Genesis Guide**. This comprehensive guide will walk you through the steps to join the Genesis of the `vector-chain` by setting up your validator node, configuring necessary variables, and submitting your genesis transaction.

---

## Table of Contents

1. [Set Environment Variables](#set-environment-variables)
2. [Install Validator Binary](#install-validator-binary)
3. [Initialize Validator](#initialize-validator)
4. [Add Mnemonic to Validator](#add-mnemonic-to-validator)
5. [Generate Genesis Transaction](#generate-genesis-transaction)

---

## Set Environment Variables

Set various environment variables to simplify the setup process.

```bash
# Home directory of the node
export VECTOR_HOME=$HOME/.vectord

# Chain ID of the vector chain
export VECTOR_CHAIN_ID=vector-1 # Do not edit me!

# Git tag of the vector-chain code used for genesis
export VECTOR_GENESIS_TAG=v1.0.0 # Do not edit me!
```

Modify and set the following environment variables to configure your validator node.

```bash
# The maximum commission change rate percentage (per day)
export VECTOR_COMMISSION_MAX_CHANGE_RATE= # Edit me!

# The maximum commission rate percentage
export VECTOR_COMMISSION_MAX_RATE= # Edit me!

# The initial commission rate percentage
export VECTOR_COMMISSION_RATE= # Edit me!

# The validator's details
export VECTOR_DETAILS= # Edit me!

# The identity signature
export VECTOR_IDENTITY= # Edit me!

# Name of the validators private key with which to sign
export VECTOR_KEY_NAME= # Edit me!

# The minimum self delegation required on the validator
export VECTOR_MIN_SELF_DELEGATION= # Edit me!

# The validator's moniker
export VECTOR_MONIKER= # Edit me!

# The validator's security contact email
export VECTOR_SECURITY_CONTACT= # Edit me!

# The validator's website
export VECTOR_WEBSITE= # Edit me!
```

## Install Validator Binary

Execute the following commands to clone the `vector-chain` repository in your home directory and install the `vector-chain` binary for the genesis event:

```bash
# Enter the home directory
cd $HOME

# Clone the official vector-chain repository
git clone git@github.com:vector-org/vector-chain.git

# Enter the cloned repository
cd vector-chain

# Checkout to the genesis tag
git checkout $VECTOR_GENESIS_TAG

# Build and install the vector-chain binary
make install
```

Verify your installation:

```bash
vectord version
```

You should see the version matching the _$VECTOR_GENESIS_TAG_.

## Initialize Validator

Initialize the validator:

```bash
vectord init $VECTOR_MONIKER --home $VECTOR_HOME
```

Confirm the validator initialization was successful by checking if the _config_ and _data_ directories have been created.

```bash
ls $VECTOR_HOME
```

> [!CAUTION]
> Backup _node_key_ and _priv_validator_key_.

## Add Mnemonic to Validator

Create a new operating key or use an existing one with the `--recover` flag.

```bash
vectord keys add $VECTOR_KEY_NAME --home $VECTOR_HOME
```

> [!CAUTION]
> Backup your mnemonic.

Confirm your key has been added.

```bash
vectord keys list
```

## Generate Genesis Transaction

Add your genesis account and credit it 10 VCTR:

```bash
vectord genesis add-genesis-account $VECTOR_KEY_NAME 10000000uvctr \
--chain-id $VECTOR_CHAIN_ID  \
--home $VECTOR_HOME
```

Create your genesis transaction:

```bash
vectord genesis gentx $VECTOR_KEY_NAME 1000000uvctr \
--commission-max-change-rate $VECTOR_COMMISSION_MAX_CHANGE_RATE \
--commission-max-rate $VECTOR_COMMISSION_MAX_RATE \
--commission-rate $VECTOR_COMMISSION_RATE \
--details $VECTOR_DETAILS \
--identity $VECTOR_IDENTITY \
--min-self-delegation $VECTOR_MIN_SELF_DELEGATION \
--moniker $VECTOR_MONIKER \
--website $VECTOR_WEBSITE \
--security-contact $VECTOR_SECURITY_CONTACT \
--chain-id $VECTOR_CHAIN_ID \
--home $VECTOR_HOME
```

Please take your genesis transaction and submit it to GitHub!

> [!TIP]
> Use Grafana for monitoring and alerting, Prometheus for metric scraping, and Loki for logging

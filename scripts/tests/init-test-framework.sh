#!/bin/bash

# Common variables
export BINARY=${BINARY:-vectord}
export DENOM=${DENOM:-uvctr}
export KEYRING="test"
export KEYALGO="secp256k1"

# Chain 1 configuration
export CHAIN_DIR="data"
export CHAIN_1_ID="test1"
export CHAIN_1_MONIKER="validator-1"
export CHAIN_1_HOME="$CHAIN_DIR/$CHAIN_1_ID"
export CHAIN_1_RPC=16657
export CHAIN_1_P2P=16656
export CHAIN_1_REST=1316
export CHAIN_1_GRPC=8090
export CHAIN_1_GRPC_WEB=8091
export CHAIN_1_ROSETTA=8080

# Chain 2 configuration
export CHAIN_2_ID="test2"
export CHAIN_2_MONIKER="validator-2"
export CHAIN_2_HOME="$CHAIN_DIR/$CHAIN_2_ID"
export CHAIN_2_RPC=26657
export CHAIN_2_P2P=26656
export CHAIN_2_REST=1317
export CHAIN_2_GRPC=9090
export CHAIN_2_GRPC_WEB=9091
export CHAIN_2_ROSETTA=8081

# Block time
export BLOCK_TIME="1s"

# Mnemonics for different accounts
VAL_MNEMONIC_1="clock post desk civil pottery foster expand merit dash seminar song memory figure uniform spice circle try happy obvious trash crime hybrid hood cushion"
VAL_MNEMONIC_2="angry twist harsh drastic left brass behave host shove marriage fall update business leg direct reward object ugly security warm tuna model broccoli choice"
WALLET_MNEMONIC_1="banner spread envelope side kite person disagree path silver will brother under couch edit food venture squirrel civil budget number acquire point work mass"
WALLET_MNEMONIC_2="veteran try aware erosion drink dance decade comic dawn museum release episode original list ability owner size tuition surface ceiling depth seminar capable only"
WALLET_MNEMONIC_3="vacuum burst ordinary enact leaf rabbit gather lend left chase park action dish danger green jeans lucky dish mesh language collect acquire waste load"
WALLET_MNEMONIC_4="open attitude harsh casino rent attitude midnight debris describe spare cancel crisp olive ride elite gallery leaf buffalo sheriff filter rotate path begin soldier"
RLY_MNEMONIC_1="alley afraid soup fall idea toss can goose become valve initial strong forward bright dish figure check leopard decide warfare hub unusual join cart"
RLY_MNEMONIC_2="record gift you once hip style during joke field prize dust unique length more pencil transfer quit train device arrive energy sort steak upset"

# Check if binary exists
if [ -z `which $BINARY` ]; then
    make install
    if [ -z `which $BINARY` ]; then
        echo "Ensure $BINARY is installed and in your PATH"
        exit 1
    fi
fi

command -v $BINARY > /dev/null 2>&1 || { echo >&2 "$BINARY command not found. Ensure this is setup / properly installed in your GOPATH (make install)."; exit 1; }
command -v jq > /dev/null 2>&1 || { echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"; exit 1; }

# Initialize chain function
init_chain() {
    local home_dir=$1
    local chain_id=$2
    local moniker=$3

    # Remove existing data
    rm -rf $home_dir

    # Set config
    $BINARY config set client chain-id $chain_id --home $home_dir
    $BINARY config set client keyring-backend $KEYRING --home $home_dir

    # Add keys
    add_keys() {
        local prefix=$1
        local mnemonic=$2
        
        echo "Adding key '$prefix' with mnemonic:"
        echo "$mnemonic"
        echo "Command: $BINARY keys add $prefix --keyring-backend $KEYRING --algo $KEYALGO --recover --home $home_dir"
        echo "$mnemonic" | $BINARY keys add "${prefix}" --keyring-backend $KEYRING --algo $KEYALGO --recover --home $home_dir
    }

    # Add all keys
    if [ "$chain_id" = "$CHAIN_1_ID" ]; then
        add_keys "val1" "$VAL_MNEMONIC_1"
        add_keys "wallet1" "$WALLET_MNEMONIC_1"
        add_keys "wallet3" "$WALLET_MNEMONIC_3"
        add_keys "rly1" "$RLY_MNEMONIC_1"
    else
        add_keys "val2" "$VAL_MNEMONIC_2"
        add_keys "wallet2" "$WALLET_MNEMONIC_2"
        add_keys "wallet4" "$WALLET_MNEMONIC_4"
        add_keys "rly2" "$RLY_MNEMONIC_2"
    fi

    echo "Initializing chain $chain_id with moniker $moniker"
    $BINARY init $moniker --chain-id $chain_id --default-denom $DENOM --home $home_dir &>/dev/null


    # Get addresses
    if [ "$chain_id" = "$CHAIN_1_ID" ]; then
        VAL1_ADDR=$($BINARY keys show val1 --home $home_dir --keyring-backend test -a)
        WALLET1_ADDR=$($BINARY keys show wallet1 --home $home_dir --keyring-backend test -a)
        WALLET3_ADDR=$($BINARY keys show wallet3 --home $home_dir --keyring-backend test -a)
        RLY1_ADDR=$($BINARY keys show rly1 --home $home_dir --keyring-backend test -a)

        # Add genesis accounts
        $BINARY genesis add-genesis-account $VAL1_ADDR "1000000000000${DENOM}" --home $home_dir
        $BINARY genesis add-genesis-account $WALLET1_ADDR "1000000000000${DENOM}" --home $home_dir
        $BINARY genesis add-genesis-account $WALLET3_ADDR "1000000000000${DENOM}" --vesting-amount "10000000000${DENOM}" --vesting-start-time $(date +%s) --vesting-end-time $(($(date '+%s') + 100000023)) --home $home_dir
        $BINARY genesis add-genesis-account $RLY1_ADDR "1000000000000${DENOM}" --home $home_dir
    else
        VAL2_ADDR=$($BINARY keys show val2 --home $home_dir --keyring-backend test -a)
        WALLET2_ADDR=$($BINARY keys show wallet2 --home $home_dir --keyring-backend test -a)
        WALLET4_ADDR=$($BINARY keys show wallet4 --home $home_dir --keyring-backend test -a)
        RLY2_ADDR=$($BINARY keys show rly2 --home $home_dir --keyring-backend test -a)

        # Add genesis accounts
        $BINARY genesis add-genesis-account $VAL2_ADDR "1000000000000${DENOM}" --home $home_dir
        $BINARY genesis add-genesis-account $WALLET2_ADDR "1000000000000${DENOM}" --home $home_dir
        $BINARY genesis add-genesis-account $WALLET4_ADDR "1000000000000${DENOM}" --vesting-amount "10000000000${DENOM}" --vesting-start-time $(date +%s) --vesting-end-time $(($(date '+%s') + 100000023)) --home $home_dir
        $BINARY genesis add-genesis-account $RLY2_ADDR "1000000000000${DENOM}" --home $home_dir
    fi

    # Update genesis
    update_test_genesis() {
        cat $home_dir/config/genesis.json | jq "$1" > $home_dir/config/tmp_genesis.json && mv $home_dir/config/tmp_genesis.json $home_dir/config/genesis.json
    }

    # Core modules
    update_test_genesis '.consensus_params["block"]["max_gas"]="100000000"'
    update_test_genesis `printf '.app_state["gov"]["params"]["min_deposit"]=[{"denom":"%s","amount":"1000000"}]' $DENOM`
    update_test_genesis '.app_state["gov"]["params"]["voting_period"]="30s"'
    update_test_genesis '.app_state["gov"]["params"]["expedited_voting_period"]="15s"'
    update_test_genesis `printf '.app_state["staking"]["params"]["bond_denom"]="%s"' $DENOM`
    update_test_genesis '.app_state["staking"]["params"]["min_commission_rate"]="0.050000000000000000"'
    update_test_genesis `printf '.app_state["mint"]["params"]["mint_denom"]="%s"' $DENOM`
    update_test_genesis `printf '.app_state["crisis"]["constant_fee"]={"denom":"%s","amount":"1000"}' $DENOM`

    # Custom modules
    update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_fee"]=[]'
    update_test_genesis '.app_state["tokenfactory"]["params"]["denom_creation_gas_consume"]=100000'

    # Generate genesis transaction
    if [ "$chain_id" = "$CHAIN_1_ID" ]; then
        $BINARY genesis gentx val1 7000000000$DENOM --keyring-backend $KEYRING --chain-id $chain_id --home $home_dir
    else
        $BINARY genesis gentx val2 7000000000$DENOM --keyring-backend $KEYRING --chain-id $chain_id --home $home_dir
    fi

    $BINARY genesis collect-gentxs --home $home_dir
    $BINARY genesis validate-genesis --home $home_dir
}

# Update configuration files
update_config() {
    local home_dir=$1
    local rpc=$2
    local p2p=$3
    local rest=$4
    local grpc=$5
    local grpc_web=$6
    local rosetta=$7

    # RPC
    sed -i -e "s/laddr = \"tcp:\/\/127.0.0.1:26657\"/c\laddr = \"tcp:\/\/0.0.0.0:$rpc\"/g" $home_dir/config/config.toml
    sed -i -e 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' $home_dir/config/config.toml

    # REST
    sed -i -e "s/address = \"tcp:\/\/localhost:1317\"/address = \"tcp:\/\/0.0.0.0:$rest\"/g" $home_dir/config/app.toml
    sed -i -e 's/enable = false/enable = true/g' $home_dir/config/app.toml
    sed -i -e 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' $home_dir/config/app.toml

    # P2P
    sed -i -e "s/laddr = \"tcp:\/\/0.0.0.0:26656\"/laddr = \"tcp:\/\/0.0.0.0:$p2p\"/g" $home_dir/config/config.toml

    # GRPC
    sed -i -e "s/address = \"localhost:9090\"/address = \"0.0.0.0:$grpc\"/g" $home_dir/config/app.toml
    sed -i -e "s/address = \"localhost:9091\"/address = \"0.0.0.0:$grpc_web\"/g" $home_dir/config/app.toml

    # Rosetta
    sed -i -e "s/address = \":8080\"/address = \"0.0.0.0:$rosetta\"/g" $home_dir/config/app.toml

    # Block time
    sed -i -e "s/timeout_commit = \"5s\"/timeout_commit = \"$BLOCK_TIME\"/g" $home_dir/config/config.toml
}

# Initialize both chains
echo "Initializing $CHAIN_1_ID & $CHAIN_2_ID..."
init_chain $CHAIN_1_HOME $CHAIN_1_ID $CHAIN_1_MONIKER 
init_chain $CHAIN_2_HOME $CHAIN_2_ID $CHAIN_2_MONIKER 

# Update configurations
echo "Updating configuration files..."
update_config $CHAIN_1_HOME $CHAIN_1_RPC $CHAIN_1_P2P $CHAIN_1_REST $CHAIN_1_GRPC $CHAIN_1_GRPC_WEB $CHAIN_1_ROSETTA
update_config $CHAIN_2_HOME $CHAIN_2_RPC $CHAIN_2_P2P $CHAIN_2_REST $CHAIN_2_GRPC $CHAIN_2_GRPC_WEB $CHAIN_2_ROSETTA

# Start chains
echo "Starting $CHAIN_1_ID in $CHAIN_DIR..."
echo "Creating log file at $CHAIN_DIR/$CHAIN_1_ID.log"
$BINARY start --home $CHAIN_1_HOME \
    --pruning=nothing \
    --minimum-gas-prices=0$DENOM \
    --grpc.address="0.0.0.0:$CHAIN_1_GRPC" \
    --rpc.laddr="tcp://0.0.0.0:$CHAIN_1_RPC" \
    > $CHAIN_DIR/$CHAIN_1_ID.log 2>&1 &

echo "Starting $CHAIN_2_ID in $CHAIN_DIR..."
echo "Creating log file at $CHAIN_DIR/$CHAIN_2_ID.log"
$BINARY start --home $CHAIN_2_HOME \
    --pruning=nothing \
    --minimum-gas-prices=0$DENOM \
    --grpc.address="0.0.0.0:$CHAIN_2_GRPC" \
    --rpc.laddr="tcp://0.0.0.0:$CHAIN_2_RPC" \
    > $CHAIN_DIR/$CHAIN_2_ID.log 2>&1 &

# Wait for chains to start
sleep 5

# Check if chains are running
if ! nc -z localhost $CHAIN_1_RPC; then
    echo "ERROR: Chain 1 failed to start. Check logs at $CHAIN_DIR/$CHAIN_1_ID.log"
    exit 1
fi

if ! nc -z localhost $CHAIN_2_RPC; then
    echo "ERROR: Chain 2 failed to start. Check logs at $CHAIN_DIR/$CHAIN_2_ID.log"
    exit 1
fi

echo "Both chains started successfully!"
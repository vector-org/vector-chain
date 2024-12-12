#!/bin/bash

# the upgrade is a fork, "true" otherwise
FORK=${FORK:-"false"}


# keys
KEY="acc0"
KEY2="acc1"

# upgrade
OLD_VERSION=v1.0.0
UPGRADE_WAIT=${UPGRADE_WAIT:-20}
HOME=mytestnet
ROOT=$(pwd)
DENOM=uvctr
CHAIN_ID=localchain-1
SOFTWARE_UPGRADE_NAME="v0.2.0"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)



if [[ "$FORK" == "true" ]]; then
    export VECTOR_HALT_HEIGHT=20
fi


# remove home dir
echo "Cleaning up..."
pkill vectord
rm -rf $HOME
mkdir -p $HOME

# underscore so that go tool will not take gocache into account
mkdir -p _build/gocache
export GOMODCACHE=$ROOT/_build/gocache

echo "Setting up old version..."
# Build old version
if [ $# -eq 1 ] && [ "$1" = "--reinstall-old" ] || ! command -v _build/old/vectord &> /dev/null; then
    echo "Building old version ($OLD_VERSION)..."
    mkdir -p _build/old
    
    # Store current branch
    echo "Current branch: $git_current_branch"
    git_current_branch=$(git rev-parse --abbrev-ref HEAD)

    echo "Checking out old version ($OLD_VERSION)"
    git checkout -q $OLD_VERSION
    git branch --show-current

    echo "Building old binary"
    GOBIN="$ROOT/_build/old" go install -mod=readonly ./...
    
    # Return to original branch
    echo "Returning to original branch ($git_current_branch)"
    git checkout -q $git_current_branch
    
    echo "Old binary built successfully"
fi

echo "Setting up new version..." 
# Build new version (current branch)
if ! command -v _build/new/vectord &> /dev/null
then
    echo "Building new version (current branch)"
    git checkout $CURRENT_BRANCH
    git branch --show-current
    mkdir -p _build/new
    GOBIN="$ROOT/_build/new" go install -mod=readonly ./...
fi

echo "Running old node..."
# run old node
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Running on macOS"
    screen -L -dmS node1 bash scripts/test_node.sh _build/old/vectord $DENOM --Logfile $HOME/log-screen.txt
else
    echo "Running on Linux"
    screen -L -Logfile $HOME/log-screen.txt -dmS node1 bash scripts/test_node.sh _build/old/vectord $DENOM
fi

sleep 5


run_fork () {
    echo "forking"

    while true; do
        BLOCK_HEIGHT=$(./_build/old/vectord status | jq '.SyncInfo.latest_block_height' -r)
        # if BLOCK_HEIGHT is not empty
        if [ ! -z "$BLOCK_HEIGHT" ]; then
            echo "BLOCK_HEIGHT = $BLOCK_HEIGHT"
            sleep 10
        else
            echo "BLOCK_HEIGHT is empty, forking"
            break
        fi
    done
}

run_upgrade () {
    echo -e "\n\n=> =>start upgrading"

    # Get upgrade height, 20 blocks after current height
    STATUS_INFO=($(./_build/old/vectord status --home $HOME | jq -r '.sync_info.latest_block_height'))
    UPGRADE_HEIGHT=$((STATUS_INFO + 20))
    echo "UPGRADE_HEIGHT = $UPGRADE_HEIGHT"

    tar -cf ./_build/new/vectord.tar -C ./_build/new vectord
    SUM=$(shasum -a 256 ./_build/new/vectord.tar | cut -d ' ' -f1)

    # Create proposal json
    cat > proposal.json << EOF
{
    "messages": [
        {
            "@type": "/cosmos.upgrade.v1beta1.MsgSoftwareUpgrade",
            "authority": "vector10d07y265gmmuvt4z0w9aw880jnsr700j53vrug",
            "plan": {
                "name": "$SOFTWARE_UPGRADE_NAME",
                "time": "0001-01-01T00:00:00Z",
                "height": "$UPGRADE_HEIGHT",
                "info": "test",
                "upgraded_client_state": null
            }
        }
    ],
    "metadata": "ipfs://CID",
    "deposit": "200000${DENOM}",
    "title": "Software Upgrade $SOFTWARE_UPGRADE_NAME",
    "summary": "Upgrade to version $SOFTWARE_UPGRADE_NAME"
}
EOF

    echo "submit upgrade"
    echo "Proposal content:"
    cat proposal.json

    ./_build/old/vectord tx gov submit-proposal proposal.json \
        --from=$KEY \
        --keyring-backend=test \
        --chain-id=$CHAIN_ID \
        --home=$HOME \
        -y
    sleep 3

    echo "Deposit"
    ./_build/old/vectord tx gov deposit 1 "10000000${DENOM}" \
        --from $KEY \
        --keyring-backend test \
        --chain-id $CHAIN_ID \
        --home $HOME \
        --gas 2000000 \
        --fees 1000000$DENOM \
        -y > /dev/null

    sleep 2

    echo "Vote proposal validator1"
    ./_build/old/vectord tx gov vote 1 yes \
        --from $KEY \
        --keyring-backend test \
        --chain-id $CHAIN_ID \
        --home $HOME \
        --gas 2000000 \
        --fees 1000000$DENOM \
        -y > /dev/null

    sleep 3

    echo "Vote proposal validator2"
    ./_build/old/vectord tx gov vote 1 yes \
        --from $KEY2 \
        --keyring-backend test \
        --chain-id $CHAIN_ID \
        --home $HOME \
        --gas 2000000 \
        --fees 1000000$DENOM \
        -y > /dev/null

    sleep 5

    # determine block_height to halt
    while true; do
        BLOCK_HEIGHT=$(./_build/old/vectord status | jq '.SyncInfo.latest_block_height' -r)
        if [ $BLOCK_HEIGHT = "$UPGRADE_HEIGHT" ]; then
            # assuming running only 1 vectord
            echo "BLOCK HEIGHT = $UPGRADE_HEIGHT REACHED, KILLING OLD ONE"
            pkill vectord
            break
        else
            ./_build/old/vectord q gov proposal 1 --output=json | jq ".status"
            echo "BLOCK_HEIGHT = $BLOCK_HEIGHT"
            sleep 1
        fi
    done
}

# if FORK = true
if [[ "$FORK" == "true" ]]; then
    run_fork
    unset VECTOR_HALT_HEIGHT
else
    run_upgrade
fi

sleep 1

# run new node
echo -e "\n\n=> =>continue running nodes after upgrade"
if [[ "$OSTYPE" == "darwin"* ]]; then
    CONTINUE="true" screen -L -dmS node1 bash scripts/run-node.sh _build/new/vectord $DENOM
else
    CONTINUE="true" screen -L -dmS node1 bash scripts/run-node.sh _build/new/vectord $DENOM
fi

sleep 5
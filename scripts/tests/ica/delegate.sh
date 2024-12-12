#!/bin/bash

echo ""
echo "###########################################"
echo "# ICA Cross Chain Delegation to Validator #"
echo "###########################################"
echo ""

BINARY=vectord
CHAIN_DIR=$(pwd)/data
CHAIN_ID_1=test1
CHAIN_ID_2=test2
GAS=2000000
FEES=1000000uvctr

# Get wallet addresses from the initialized test framework
WALLET_1=$($BINARY keys show val1 -a --keyring-backend test --home $CHAIN_DIR/$CHAIN_ID_1)
WALLET_2=$($BINARY keys show val2 -a --keyring-backend test --home $CHAIN_DIR/$CHAIN_ID_2)

echo "Registering ICA on chain test1"
TX_HASH=$($BINARY tx interchain-accounts controller register connection-0 --from $WALLET_1 --chain-id $CHAIN_ID_1 --home $CHAIN_DIR/$CHAIN_ID_1 --node tcp://localhost:16657 --keyring-backend test --gas "$GAS" --fees "$FEES" -y -o json| jq -r '.txhash')
echo "TX_HASH: $TX_HASH"
sleep 3

echo "Waiting for ICA registration to complete..."
ICA_ADDRESS=""
while [ -z "$ICA_ADDRESS" ] || [ "$ICA_ADDRESS" == "null" ]; do
    sleep 2
    ICA_ADDRESS=$($BINARY query interchain-accounts controller interchain-account $WALLET_1 connection-0 --node tcp://localhost:16657 -o json | jq -r '.address')
    echo "ICA Address: $ICA_ADDRESS"
done

echo "SUCCESS: ICA registered with address $ICA_ADDRESS"
echo "----------------------------------------"

# echo "Sending tokens to ICA on chain test2"
# TX_HASH=$($BINARY tx bank send $WALLET_2 $ICA_ADDRESS 10000000$DENOM --chain-id $CHAIN_ID_2 --home $CHAIN_DIR/$CHAIN_ID_2 --gas "$GAS" --fees "$FEES" --node tcp://localhost:26657 --keyring-backend test -y | jq -r '.txhash')
# echo "TX_HASH: $TX_HASH"
# sleep 3

# echo "Verifying ICA received tokens..."
# ICA_BALANCE=$($BINARY query bank balances $ICA_ADDRESS --chain-id $CHAIN_ID_2 --node tcp://localhost:26657 -o json | jq -r '.balances[0].amount')
# if [ "$ICA_BALANCE" != "10000000" ]; then
#     echo "ERROR: ICA has not received tokens. Expected 10000000, got $ICA_BALANCE"
#     exit 1
# fi

# echo "SUCCESS: ICA received 10000000$DENOM"
# echo "----------------------------------------"

# echo "Executing Delegation from test1 to test2 via ICA"
# VAL_ADDR=$($BINARY query staking validators --node tcp://localhost:26657 -o json | jq -r '.validators[0].operator_address')

# PACKET_DATA=$($BINARY tx interchain-accounts host generate-packet-data '{
#     "@type":"/cosmos.staking.v1beta1.MsgDelegate",
#     "delegator_address": "'"$ICA_ADDRESS"'",
#     "validator_address": "'"$VAL_ADDR"'",
#     "amount": {
#         "denom": "'"$DENOM"'",
#         "amount": "10000000"
#     }
# }' --memo "ICA delegation" --encoding proto3)

# TX_HASH=$($BINARY tx interchain-accounts controller send-tx connection-0 "$PACKET_DATA" --from $WALLET_1 --chain-id $CHAIN_ID_1 --home $CHAIN_DIR/$CHAIN_ID_1 --gas "$GAS" --fees "$FEES" --node tcp://localhost:16657 --keyring-backend test -y | jq -r '.txhash')
# echo "TX_HASH: $TX_HASH"
# sleep 3

# echo "Waiting for delegation to complete..."
# DELEGATION_AMOUNT=""
# while [ "$DELEGATION_AMOUNT" != "10000000" ]; do
#     sleep 2
#     DELEGATION_AMOUNT=$($BINARY query staking delegations-to $VAL_ADDR --home $CHAIN_DIR/$CHAIN_ID_2 --node tcp://localhost:26657 -o json | jq -r '.delegation_responses[-1].balance.amount')
#     echo "Current delegation amount: $DELEGATION_AMOUNT"
# done

# echo ""
# echo "####################################################"
# echo "# SUCCESS: ICA Cross Chain Delegation to Validator  #"
# echo "####################################################"
# echo ""
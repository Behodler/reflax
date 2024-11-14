#!/bin/bash
direnv allow
sleep 2
echo "debug up to coming"
echo $DebugUpTo
yarn anvil-down
# Determine the directory where the script is located.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Change to the directory where the script is located.
cd "$SCRIPT_DIR"

# Specify log file location
LOG_FILE="../anvil.log"

# Start anvil in the background and redirect all output to log file
anvil -f $RPC_URL --block-time 1 --port 8545 --accounts 10 >"$LOG_FILE" 2>&1 &

# # Get the PID of the anvil process
ANVIL_PID=$!
echo $ANVIL_PID >AnvilID.txt

echo "Anvil started with PID $ANVIL_PID and stored in Redis"

echo "sleeping 10 for anvil"
sleep 10
# Step 2: Deploy contracts and update addresses.json
# forge script ./DeployContracts.s.sol --broadcast --rpc-url=http://localhost:8545 --json | jq -r '.[] | .name + ":" + .address' >> ../addresses.json
# forge script ./DeployContracts.s.sol --tc DeployContracts --broadcast --rpc-url=http://localhost:8545 --json

echo $RPC_URL
touch addresses.txt && rm addresses.txt && forge script --ffi --rpc-url=http://localhost:8545 ./DeployContracts.s.sol --slow -g 200 --gas-limit 80000000 --via-ir --tc DeployContracts --broadcast --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

echo "executing node script"
# node updateRedis.js
sleep 5
node expressServer

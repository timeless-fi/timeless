# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/arbitrum.json
export RPC_URL=$RPC_URL_ARBITRUM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
factory_address=$(deploy Factory $PROTOCOL_FEE_ARBITRUM)
echo "Factory=$factory_address"

send $factory_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_ARBITRUM true false
echo "FactoryOwner=$INITIAL_OWNER_ARBITRUM"

yearn_gate_address=$(deploy YearnGate $factory_address)
echo "YearnGate=$yearn_gate_address"

send $yearn_gate_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_ARBITRUM true false
echo "YearnGateOwner=$INITIAL_OWNER_ARBITRUM"

erc4626_gate_address=$(deploy ERC4626Gate $factory_address)
echo "ERC4626Gate=$erc4626_gate_address"

send $erc4626_gate_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_ARBITRUM true false
echo "ERC4626GateOwner=$INITIAL_OWNER_ARBITRUM"
# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/rinkeby.json
export RPC_URL=$RPC_URL_RINKEBY

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
factory_address=$(deploy Factory $PROTOCOL_FEE_RINKEBY)
echo "Factory=$factory_address"

send $factory_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_RINKEBY true false
echo "FactoryOwner=$INITIAL_OWNER_RINKEBY"

yearn_gate_address=$(deploy YearnGate $factory_address)
echo "YearnGate=$yearn_gate_address"

erc4626_gate_address=$(deploy ERC4626Gate $factory_address)
echo "ERC4626Gate=$erc4626_gate_address"
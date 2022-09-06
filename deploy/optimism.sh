# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/optimism.json
export RPC_URL=$RPC_URL_OPTIMISM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
factory_address=$(deployViaCast Factory 'constructor((uint8,address))' $PROTOCOL_FEE_OPTIMISM)
echo "Factory=$factory_address"

send $factory_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_OPTIMISM true false
echo "FactoryOwner=$INITIAL_OWNER_OPTIMISM"

yearn_gate_address=$(deployViaCast YearnGate 'constructor(address)' $factory_address)
echo "YearnGate=$yearn_gate_address"

send $yearn_gate_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_OPTIMISM true false
echo "YearnGateOwner=$INITIAL_OWNER_OPTIMISM"

erc4626_gate_address=$(deployViaCast ERC4626Gate 'constructor(address)' $factory_address)
echo "ERC4626Gate=$erc4626_gate_address"

send $erc4626_gate_address "transferOwnership(address,bool,bool)" $INITIAL_OWNER_OPTIMISM true false
echo "ERC4626GateOwner=$INITIAL_OWNER_OPTIMISM"
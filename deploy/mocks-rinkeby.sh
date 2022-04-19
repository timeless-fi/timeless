# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/mocks-rinkeby.json
export RPC_URL=$RPC_URL_RINKEBY

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
test_erc20_address=$(deploy TestERC20 18)
echo "TestERC20=$test_erc20_address"

test_erc4626_address=$(deploy TestERC4626 $test_erc20_address)
echo "TestERC4626=$test_erc4626_address"

test_yearnvault_address=$(deploy TestYearnVault $test_erc20_address)
echo "TestYearnVault=$test_yearnvault_address"
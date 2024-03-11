set dotenv-load
set export

# contract deployments
deploy_earthmind_nft JSON_RPC_URL SENDER:
    echo "Deploying EarthMind NFT"
    forge script script/v1/001_EarthMind_Deploy.s.sol:EarthMindDeployScript --rpc-url $JSON_RPC_URL --sender $SENDER --broadcast --verify --ffi -vvvv

deploy_local:
    echo "Deploying contracts locally"
    NETWORK_ID=$CHAIN_ID_LOCAL MNEMONIC=$MNEMONIC_LOCAL just deploy_earthmind_nft $RPC_URL_LOCAL $SENDER_LOCAL

deploy_sepolia:
    echo "Deploying contracts to Sepolia testnet"
    NETWORK_ID=$CHAIN_ID_SEPOLIA MNEMONIC=$MNEMONIC_SEPOLIA just deploy_earthmind_nft $RPC_URL_SEPOLIA $SENDER_SEPOLIA

deploy_mainnet:
    echo "Deploying contracts to Mainnet"
    NETWORK_ID=$CHAIN_ID_MAINNET MNEMONIC=$MNEMONIC_MAINNET just deploy_earthmind_nft $RPC_URL_MAINNET $SENDER_MAINNET

# contract interactions
request_and_approve: # used to request and approve NFT in Sepolia testnet
    echo "Requesting and approving NFT"
    NETWORK_ID=$CHAIN_ID_SEPOLIA MNEMONIC=$MNEMONIC_SEPOLIA forge script script/v1/Request_And_Approve.s.sol:RequestAndApproveScript --rpc-url $RPC_URL_SEPOLIA --sender $SENDER_SEPOLIA --broadcast --ffi -vvvv

# orchestration and testing
test_unit:
    echo "Running unit tests"
    forge test --match-path "test/unit/**/*.sol"

test_coverage:
    forge coverage --report lcov 
    lcov --remove ./lcov.info --output-file ./lcov.info 'script' 'DeployerUtils.sol' 'DeploymentUtils.sol' 'v2' 'v3'
    genhtml lcov.info -o coverage --branch-coverage --ignore-errors category

test CONTRACT:
    forge test --mc {{CONTRACT}} -vvvv

test_only CONTRACT TEST:
    forge test --mc {{CONTRACT}} --mt {{TEST}} -vv
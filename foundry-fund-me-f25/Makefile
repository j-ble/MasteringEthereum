-include .env

build:; forge build

deploy-sepolia:; forge script script/DeployFundMe.s.sol:DeployFundMe --rpc-url $(RPC_URL_SEPOLIA) --private-key $(PRIVATE_KEY_SEPOLIA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
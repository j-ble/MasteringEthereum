-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

build :
	forge build

test :
	forge test 

install : 
	forge install cyfrin/foundry-devops@0.2.2 && \
	forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && \
	forge install foundry-rs/forge-std@v1.8.2 && \
	forge install transmissions11/solmate@v6

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(RPC_URL_SEPOLIA) \
	--account metaMaskKey --broadcast --verify --etherscan-api-key $(API_KEY_ETHERSCAN) -vvvv
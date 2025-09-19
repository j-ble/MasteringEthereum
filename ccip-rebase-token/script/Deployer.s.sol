// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RegistryModuleOwnerCustom} from "@chainlink-ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

// Token and Pool Deployer is a script for deploying and configuring the RebaseToken and RebaseTokenPool contracts
contract TokenAndPoolDeployer is Script {
    // Deploys a RebaseToken and RebaseTokenPool setting up permissions and registers them in a registry
    /**
     * @return token The newly deployed RebaseToken contract
     * @return pool The newly deployed RebaseTokenPool contract
     */
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        // Deploy a CCIPLocalSimulatorFork to retrieve the network configuration details
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        // Fetch the network details for the current chain ID
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        // Deploy a new RebaseToken contract
        token = new RebaseToken();
        // Deploy a new RebaseTokenPool contract
        // - The RebaseToken address case to IERC20 for compatibility
        // - An empty array of addresses 
        // - The rmnProxyAddress for cross-chain communication
        // - The routerAddress for CCIP routing
        pool = new RebaseTokenPool(
            IERC20(address(token)), 
            18, 
            new address[](0), 
            networkDetails.rmnProxyAddress, 
            networkDetails.routerAddress
        );
        // Grant the pool contract mint and burn roles for the RebaseToken, allowing it to manage token supply
        token.grantMintAndBurnRole(address(pool));
        // Register the tokens admin roles in the custom registry module using the network registry module owner address
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(address(token));
        // Accept the admin role for the token in the TokenAdminRegistry to enable administrative control
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(token));
        // Associate the RebaseToken with its RebaseTokenPool in the TokenAdminRegistry for tracking and management
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(token), address(pool));
        vm.stopBroadcast();
    }
}
// deploys a vault contract which configures it premissions with the rebase token
contract VaultDeployer is Script {
    // Deploys a new contract and grants it mint and burn roles for the rebase token
    /**
     * @param _rebaseToken address of the deployed rebase token contract
     * @return vault newly deployed vault contract
     */
    function run(address _rebaseToken) public returns (Vault vault) {
        // Start broadcasting the transaction of the deployed RebaseToken contract
        vm.startBroadcast();
        // Deploy a new Vault contract, passing the RebaseToken address to the constructor
        vault = new Vault(IRebaseToken(_rebaseToken));
        // Grant the vault contract mint and burn roles on the RebaseToken, allowing it to manage token supply
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        // Stop broadcasting transaction to the blockchain
        vm.stopBroadcast();
    }
}
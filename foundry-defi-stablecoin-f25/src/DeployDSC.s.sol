// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {DSCEngine} from "./DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @notice This is a Foundry script to deploy the DecentralizedStableCoin (DSC) and DSCEngine contracts.
 * It uses a HelperConfig contract to handle different configurations for various networks.
 */
contract DeployDSC is Script {
    // These arrays will hold the addresses of the collateral tokens and their corresponding price feeds.
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    /**
    * @notice This is the main function that Foundry's `forge script` command executes.
    * @return dsc The deployed DecentralizedStableCoin contract instance.
    * @return engine The deployed DSCEngine contract instance.
    */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        // 1. Get Network Configuration
        // Create an instance of our helper contract to determine which network we're on.
        HelperConfig config = new HelperConfig();
        
        // Retrieve the configuration (addresses, deployer key) for the active network.
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wxrpUsdPriceFeed,
            address weth,
            address wbtc,
            address wxrp,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        // Populate our address arrays with the config data for easier use.
        tokenAddresses = [weth, wbtc, wxrp];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed, wxrpUsdPriceFeed];

        // 2. Deploy Contracts
        // This is a Foundry cheatcode. It tells the script to start broadcasting subsequent transactions
        // to the blockchain, signed by the `deployerKey`.
        vm.startBroadcast(deployerKey);
        // Deploy the DecentralizedStableCoin (ERC20 token) contract.
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        // Deploy the DSCEngine contract, which contains all the core logic.
        // We pass it the lists of approved collateral tokens, their price feeds, and the address of our DSC token.
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        // 3. Post-Deployment Setup
        // Transfer the ownership of the DSC token contract to the DSCEngine.
        // This is a CRITICAL step. It gives the DSCEngine the sole power to mint new DSC tokens.
        dsc.transferOwnership(address(engine));
        // Stop broadcasting transactions. Any state changes after this will only happen locally in the script.
        vm.stopBroadcast();
        // Return the instances of the deployed contracts.
        return (dsc, engine, config);
    }
}
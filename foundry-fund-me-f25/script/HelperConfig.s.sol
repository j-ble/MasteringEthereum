// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 1. Deploy mocks when we are on a local anvil chain
// 2. Keep track of contract addresses across different chains

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";

contract HelperConfig {
    // If we are on a local anvil chain, we can deploy the contract/mocks
    // Otherwise, grab the contract address from a live network

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    struct NetworkConfig {
        address priceFeed;  // Sepolia ETH/USD Price Feed
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory){
        // price feed address
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getAnvilEthConfig() public pure returns (NetworkConfig memory){
        // price feed address
        NetworkConfig memory anvilConfig =  NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return anvilConfig;
    }
}
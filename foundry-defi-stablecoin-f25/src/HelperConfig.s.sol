// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.t.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @notice This contract provides network-specific configurations
 * to deployment scripts. It can return real addresses for a testnet like Sepolia
 * or deploy and return mock addresses for a local development network like Anvil.
 */

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address wxrpUsdPriceFeed;
        address weth;
        address wbtc;
        address wxrp;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant XRP_USD_PRICE = 1000e8;
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;


    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            // This struct defines a data structure to hold all the necessary configuration for one network.
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wxrpUsdPriceFeed: 0x72F48eBe69eB7f5DdA2394C9EA488e621727f8B1,
            wxrp: 0xeeb78fcA54376aeE7803b1a535974842C4236ADd,
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0x2868d708e442A6a940670d26100036d426F1e16b,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    // Constants for deploying mock contracts on a local Anvil chain.
    function getOrCreateAnvilConfig() public returns(NetworkConfig memory) {
        if(activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();

        MockV3Aggregator xrpUsdPriceFeed = new MockV3Aggregator(DECIMALS, XRP_USD_PRICE);
        ERC20Mock wxrpMock = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            wxrpUsdPriceFeed: address(xrpUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            wxrp: address(wxrpMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
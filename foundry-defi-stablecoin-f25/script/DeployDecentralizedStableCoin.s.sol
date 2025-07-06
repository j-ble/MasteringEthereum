// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * Helper script to deploy the DecentralizedStableCoin contract.
 * Run with:
 *    forge script script/DeployDecentralizedStableCoin.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast -vvvv
 */

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoin is Script {
    function run() external returns (DecentralizedStableCoin dsc) {
        /**
         * vm.startBroadcast() -> every subsequent call is sent as a 
         * *real* transaction (or sumulated, depending on flags).
         * The deployer will be address derived from the first private key
         * in your env variable 'PRIVATE_KEY'.
         */
        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        vm.stopBroadcast();
    }
}
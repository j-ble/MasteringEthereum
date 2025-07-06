// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoin is Script {
    function run() external returns (DecentralizedStableCoin dsc) {
        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        vm.stopBroadcast();
    }
}
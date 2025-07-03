// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../lib/forge-std/src/Test.sol";
import {DeployBasicNft} from "../script/DeployBasicNft.s.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract DeployBasicNftTest is Test {
    DeployBasicNft private deployer;

    function setUp() public {
        deployer = new DeployBasicNft();
    }

    // This test runs the script and verifies it returns a valid contract address
    function testScriptDeploysContract() public {
        BasicNft deployedNft = deployer.run();
        // Assert that the deployment returned a non-zero address, proving success
        assertNotEq(address(deployedNft), address(0));
    }
}
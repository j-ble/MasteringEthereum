// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

/**
 * Tests that the script DeployDecentralizedStableCoin.s.sol really does deploys
 * a DecentralizedStableCoin contract.
 */
contract DeployDecentralizedStableCoinTest is Test {
    DeployDecentralizedStableCoin internal deployScript;

    // Any non-zero private key will keep the vm.startBroadcast() call in the script happy
    uint256 private constant DUMMY_PRIVATE_KEY = uint256(1);

    function setUp() public {
        // Provide the PRIVATE_KEY env-var expected by 'vm.startBroadcast()'
        vm.setEnv("PRIVATE_KEY", vm.toString(DUMMY_PRIVATE_KEY));

        deployScript = new DeployDecentralizedStableCoin();
    }

    function test_RunDeploysStableCoin() public {
        // Execute the script
        DecentralizedStableCoin dsc = deployScript.run();

        // 1. A non-zero address must be returned
        assertTrue(address(dsc) != address(0), "zero address returned");

        // 2. There must be code at that address (conttract deployed)
        uint256 codeSize;
        assembly {
            // checks byte code size at address 'dsc'
            codeSize := extcodesize(dsc)
        }
        // Code size must be greater than zero (exitsts on the test-chain)
        assertGt(codeSize, 0, "no code deployed");
    }
}
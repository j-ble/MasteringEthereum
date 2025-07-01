// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract ManualTokenTest is Test {
    ManualToken public manualToken;
    
    address public deployer;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        manualToken = new ManualToken();
        deployer = address(this);
    }

    function testNameIsCorrect() public {
        assertEq(manualToken.name(), "Manual Token");
    }

    function testTotalSupplyIsCorrect() public {
        assertEq(manualToken.totalSupply(), 100 ether);
    }

    function testDecimalsIsCorrect() public {
        assertEq(manualToken.decimals(), 18);
    }

    function testDeployerHasInitialSupply() public {
        assertEq(manualToken.balanceOf(deployer), 100 ether);
        assertEq(manualToken.balanceOf(user1), 0);
    }

    function testSuccessfulTransfer() public {
        uint256 amountToSend = 10 ether;
        bool success = manualToken.transfer(user1, amountToSend);
        assertTrue(success, "Transfer function should return true on success");
        assertEq(manualToken.balanceOf(user1), amountToSend);
        assertEq(manualToken.balanceOf(deployer), 100 ether - amountToSend);
    }

    function testTransferRevertsIfInsufficientBalance() public {
        uint256 amountToSend = 10 ether;
        vm.prank(user1); // user1 has 0 balance
        vm.expectRevert("ManualToken: Insufficient balance");
        manualToken.transfer(user2, amountToSend);
    }
}
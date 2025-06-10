// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test{
    FundMe fundMe;
    uint256 constant SEND_VALUE = 0.1 ether; // 100000000000000000 wei
    uint256 constant MINIMUM_USD = 5e18;
    uint256 constant STARTING_BALANCE = 10 ether;

    address USER = makeAddr("user");

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFuneMe = new DeployFundMe();
        fundMe = deployFuneMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), MINIMUM_USD);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.i_owner(), msg.sender);
    }

    // What can we do to work with addresses outside of our system?
    // 1. Unit
    //    - Testing a specific part of our code
    // 2. Integration
    //    - Testing the interaction between different parts of our code
    // 3. Forked
    //    - Testing our code on a simulated blockchain
    // 4. Staging
    //    - Testing our code on a real environment

    function testPriceFeedVersionIsAccurate() public view{
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // Hey, we can revert here!
        // assert, this Tx fails/reverts
        fundMe.fund(); // send 0 value
    }

    function testFundUpdatesFundedDataStructures() public {
        vm.prank(USER); // The next Tx will be sent by USER
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }
}
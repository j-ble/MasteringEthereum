// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundMeTest is Test{
    FundMe fundMe;

    function setUp() external {
        fundMe = new FundMe();
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.i_owner(), address(this));
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
    
    function testFundMeCanBeFunded() public {
        vm.deal(address(this), 1 ether);
        fundMe.fund{value: 1 ether}();
        assertEq(fundMe.addressToAmountFunded(address(this)), 1 ether);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }
}
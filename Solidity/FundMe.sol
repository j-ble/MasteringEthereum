// Get contracts from the user
// Withdrawal funds
// Set a minimum funding value in USD
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PriceConverter} from "./PriceConverter.sol";

contract FundMe {
    using PriceConverter for uint256;

    uint256 public minimumUsd = 5e18;

    address[] public funders;
    mapping(address funder => uint256 amountFunded) public addressToAmountFunded;

    address public owner;

    constructor() {
        // msg is a contract that we are using to communicate with another contract
        owner = msg.sender;
    }

    function fund () public payable {
        // Allow user to send money
        // Have a mimimum amount sent
        // How do we send ETH to this contract?
        require(msg.value.getConverstionRate() >= minimumUsd, "didn't send enough ETH");
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] += msg.value;
        // What is a revert?
        // Undo any actions that have been done, and send the remaining gas back
        
    }

    function withdrawal () public {
        require(msg.sender == owner, "Must be the contract owner");
        // for loop
        // [1, 2, 3, 4] elements
        // 0, 1, 2, 3   indexes
        // for(/* starting index, ending index. step amount */)
        for(uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        // reset the array
        funders = new address[](0);
        // withdrawal the funds

        // // trasnfer
        // payable(msg.sender).transfer(address(this).balance);

        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "failed to send ETH to fund");

        // // call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

}

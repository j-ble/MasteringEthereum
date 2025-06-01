// Get contracts from the user
// Withdrawal funds
// Set a minimum funding value in USD
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract FundMe {

    uint256 public minimumUsd = 5;

    function fund () public payable {
        // Allow user to send money
        // Have a mimimum ammount sent
        // How do we send ETH to this contract?
        require(msg.value >= minimumUsd, "didn't send enough ETH");

        // What is a revert?
        // Undo any actions that have been done, and send the remaining gas back
        
    }

    // function withdrawal () public {

    // }

    function getPrice() public view returns(uint256) {
        // address 0x694AA1769357215DE4FAC081bf1f309aDC325306
        // ABI
        AggregatorV3Interface dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        (,int256 price,,,) = dataFeed.latestRoundData();
        // Price of ETH in USD terms
        return uint256(price) * 1e10;
    }
    function getConverstionRate() public {}

    function getVersion () public view returns (uint256){
        return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
    }

    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// Get contracts from the user
// Withdrawal funds
// Set a minimum funding value in USD

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter{
    function getPrice() internal view returns(uint256) {
        // address 0x694AA1769357215DE4FAC081bf1f309aDC325306
        // ABI
        AggregatorV3Interface PriceFeed = AggregatorV3Interface(0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF);
        (,int256 price,,,) = PriceFeed.latestRoundData();
        // Price of ETH in USD terms
        return uint256(price) * 1e10;
    }
    function getConverstionRate(uint256 ethAmount) internal view returns(uint256){
        // How much is 1 ETH??
        // 2500_000000000000000000 (current ETH price)
        uint256 ethPrice = getPrice();
        // 2500_000000000000000000 * (1 ETH) 1_000000000000000000 / 1e18
        // $2500 = 1 ETH
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }

    function getVersion () internal view returns (uint256){
        return AggregatorV3Interface(0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF).version();
    }
}

// constant, immutable

// 693,483 gas - non-constant

// 506,182 gas - constant ; if and revert rather than require string variable

error NotOwner();
error NotEnoughETH();
error WithdrawalFailed();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;
    // 2424

    address[] public funders;
    mapping(address funder => uint256 amountFunded) public addressToAmountFunded;

    address public immutable i_owner;
    // 439 gas - immutable
    // 2,574 gas - non-immutable

    constructor() {
        // msg is a contract that we are using to communicate with another contract
        i_owner = msg.sender;
    }

    function fund () public payable {
        // Allow user to send money
        // Have a mimimum amount sent
        // How do we send ETH to this contract?
        if(msg.value.getConverstionRate() < MINIMUM_USD){
            revert NotEnoughETH();
        }
        // require(msg.value.getConverstionRate() >= MINIMUM_USD, "didn't send enough ETH");
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] += msg.value;
        // What is a revert?
        // Undo any actions that have been done, and send the remaining gas back
        
    }

    function withdrawal () public {
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
        if(!callSuccess) {
            revert WithdrawalFailed();
        }
        // require(callSuccess, "Call failed");
    }

    function getVersion() public view returns (uint256) {
        AggregatorV3Interface PriceFeed = AggregatorV3Interface(0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF);
        return PriceFeed.version();
    }

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Sener is not owner");
        if(msg.sender != i_owner) {revert NotOwner();}
        _;
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter{
    function getPrice() internal view returns(uint256) {
        // address 0x694AA1769357215DE4FAC081bf1f309aDC325306
        // ABI
        AggregatorV3Interface dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        (,int256 price,,,) = dataFeed.latestRoundData();
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
        return AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306).version();
    }
}
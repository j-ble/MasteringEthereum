// SPDX-License-Identifier: MIT
pragma solidity 0.8.24; // stating version

import {SimpleStorage} from "./SimpleStorage.sol";

// AddFiveStorage inherits all the components from SimpleStorage 
contract AddFiveStorage is SimpleStorage{
    // + 5
    // overrides
    // virtual overrides
    function store (uint256 _newNumber) public override {
        myFavoriteNumber = _newNumber + 5;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; // stating version

contract SimpleStorage {
    // favorite number initalized to 0 if no value
    uint256 public favoriteNumber; // defaults to 0

    function store(uint256 _favoriteNumber) public {
        favoriteNumber = _favoriteNumber;
    }

    // view, pure
    function retrieve() public view returns(uint256){
        return favoriteNumber;
    }
}
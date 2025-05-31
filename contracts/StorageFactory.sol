// SPDX-License-Identifier: MIT
pragma solidity 0.8.24; // stating version

import {SimpleStorage} from "./SimpleStorage.sol";

contract StorageFactroy{
    // uint256 public favorite number
    // type visibility name
    SimpleStorage[] public listOfSimpleStorageContracts;

    function createSimpleStorageContract() public {
        SimpleStorage newSimpleStorageContract = new SimpleStorage();
        listOfSimpleStorageContracts.push(newSimpleStorageContract);
    }
}
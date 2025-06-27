// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RevertingReceiver {
    receive() external payable {
        revert("Transfer failed in reciever");
    }
    fallback() external payable {
        revert("Transfer failed in fallback");
    }
}
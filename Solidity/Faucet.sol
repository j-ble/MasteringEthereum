// SPDX-License-Identifier: CC0-BY-SA-4.0
pragma solidity ^0.8.0;

// first contract is a faucet
contract Faucet {
    // faucet is a payable contract (accecpt any account to send Ether)
    receive() external payable {}

    // Give out ether to anyone who asks
    function withdraw(uint withdraw_amount) public {
        // limit withdrawal amount
        require(withdraw_amount <= 100000000000000000);
        
        // send the amount to the address that requested it
        msg.sender.transfer(withdraw_amount);
    }
}
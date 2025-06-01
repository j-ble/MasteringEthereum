// Get contracts from the user
// Withdrawal funds
// Set a minimum funding value in USD
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract FundMe {
    function fund () public payable {
        // Allow user to send money
        // Have a mimimum ammount sent
        // How do we send ETH to this contract?
        require(msg.value >= 1e18, "didn't send enough ETH");
    }

    // function withdrawal () public {

    // }

    
}

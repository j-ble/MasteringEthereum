// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title A sample raffle smart contract
 * @author Jacob Blemaster
 * @notice This contract is for creating a sample raffle smart contract
 * @dev Implements Chianlink VRFv2.5
 */

contract Raffel {
    /* Errors */
    error NotEnoughETH();

    uint256 private immutable i_entranceFee;
    // @dev The duration of the raffle in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /* Events */
    event RaffelEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable{
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter");
        if(msg.value < i_entranceFee){
            revert NotEnoughETH();
        }
        s_players.push(payable(msg.sender));

        emit RaffelEntered(msg.sender);
    }

    function pickWinner() public {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) { 
            revert();
        }
    }

    /** 
     * Getter Functions
    */
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }
}

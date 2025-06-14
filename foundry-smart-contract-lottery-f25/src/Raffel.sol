// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title A sample raffle smart contract
 * @author Jacob Blemaster
 * @notice This contract is for creating a sample raffle smart contract
 * @dev Implements Chianlink VRFv2.5
 */

contract Raffel {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable{

    }

    function pickWinner() public {

    }

    /** 
     * Getter Functions
    */
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }
}

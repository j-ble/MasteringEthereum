// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Types declarations
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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Jacob Blemaster
 * @notice This is a cross-chain rebase token that incentivises user to deposit into a vault
 *         and gain interest overt time. 
 * @notice The interest rate in the smart contract can only decrease over time.
 * @notice Each user will have their own interest rate the is the global interest rate.
 */

contract RebaseToken is ERC20 {

    /////////////////////
    //      Errors     //
    /////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /////////////////////
    // State Variables //
    /////////////////////
    uint256 private s_interestRate = 5e10;
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    /////////////////////
    //     Events      //
    /////////////////////
    event InterestRateSet(uint256 newInterestRate);

    /////////////////////
    //  Constructor    //
    /////////////////////
    constructor() ERC20("Rebase Token", "RBT") {}

    /////////////////////////
    //  External Functions //
    /////////////////////////
    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease over time
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if(_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }
    
    function mint(address _to, uint256 _amount) external {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /////////////////////////
    //  Internal Functions //
    /////////////////////////
    function _mintAccuredInterest(address _user) internal {
        // (1) find current balance of rebase token that have been minted to the user -> principal
        // (2) calculate their current balance including any interest -> balanceOf
        // calculate the number of tokens that need to be minted to the user (2) - (1)
        // call _mint to mint the tokens to the user
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /////////////////////////
    //  View Functions     //
    /////////////////////////
    /**
     * @notice Get the interest rate for a user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * Calculate the balance for the user including the interest that has accumulated since the last update.
     * (principal balance) + some interest that has accured
     * @param _user The user to calculate the balance for
     * @return The balance for the user including the interest that has accumulated since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the current principle balance (the number of tokens that have been minted to the user).
        // Multiply the principle balance by the interest that has accumulated in the time since the balance
        // was last updated.
        return super.balanceOf(_user) * _calculateUserAccumlatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update.
     * @param _user The user to calculate the interest accumulated for.
     */
    function _calculateUserAccumlatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // We need to calculate the interest that has accumulated since the last update
        // This is going to be linear growth with timed
        // 1. Calculate the time since the alst update
        // 2. Calculate the amount of linear growth
        // principal amount (1 + (principal amount * user interest rate * time elapsed))   
        // deposit: 10 tokens
        // interest rate is 0.5 tokens per second
        // time elapsed is 2 seconds 
        // 10 + (10 * 0.5 * 2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = (PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed));
    }
}
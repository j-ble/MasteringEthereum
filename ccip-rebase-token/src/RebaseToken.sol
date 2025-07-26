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

/////////////////////
//     Imports     //
/////////////////////
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

//////////////////////////////////////////////
//     interfaces, libraries, contracts     //
//////////////////////////////////////////////
/**
 * @title RebaseToken
 * @author Jacob Blemaster
 * @notice This is a cross-chain rebase token that incentivises user to deposit into a vault
 *         and gain interest overt time. 
 * @notice The interest rate in the smart contract can only decrease over time.
 * @notice Each user will have their own interest rate the is the global interest rate.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /////////////////////
    //      Errors     //
    /////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    /////////////////////
    // State Variables //
    /////////////////////
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
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
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender){}

    /////////////////////////
    //  External Functions //
    /////////////////////////
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }
    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease over time
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner{
        if(_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }
    
    /**
     * @notice Mint the user tokens when they deploy into the vault
     * @param _to The user to mint the tokens to 
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccuredInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterest(_from);
        _burn(_from, _amount);
    }

    /////////////////////////
    //  Public Functions   //
    /////////////////////////
    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(msg.sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Tranfer tokens from one user to another
     * @param _sender The user to transfer the tokens from 
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccuredInterest(_sender);
        _mintAccuredInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /////////////////////////
    //  Internal Functions //
    /////////////////////////
    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccuredInterest(address _user) internal {
        // (1) find current balance of rebase token that have been minted to the user -> principal balance
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint to mint the tokens to the user
        _mint(_user, balanceIncrease);
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
     * @notice Get the interest rate that is currently set for the contract. Any future depositors will recieve this interest rate
     * @return The interest rate for the contract
     */
    function getInerestRate() external view returns (uint256) {
        return s_interestRate;
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

    /**
     * @notice Get the principle balance of a user. This is the number of tokens that have been minted to the user, not including any interest that has been accrued.
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
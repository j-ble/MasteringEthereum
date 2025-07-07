// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.18;

/**
 * @title DSCEngine
 * @author Jacob Blemaster
 * 
 * The system is designed to be as minimal as possible,
 * and have the tokens maintain a 1 token == $1 peg.
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 * 
 * It is similar to DAI if DAI had no governance, no fees, 
 * and was only backed by wETH, wBTC, and wXRP. 
 * 
 * Our DSC system should always be "overcollateralized". At no point, should the value of 
 * all collateral <= the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSC,
 * as well as depositing & withdrawing collateral. 
 * @notice This contract is VERY loosely based on the Sky project in which Dai generates Single-Collateral Dai (SDC), or Sai. 
 */
contract DSCEngine {
    function depositCollateralAndMintDsc() external {}

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    // Example of value of collateral dropping to much:
    // $2000 ETH -> $400 ETH
    // $500 DSC -> Liquidated

    // Example of setting a %150 threshold:
    // $2000 ETH -> MUST HAVE $750 ETH 
    // $500 DSC

    function redeemCollateral() external {}

    function mintDsc() external {}
        
    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract ManualToken {
    mapping(address => uint256) private s_balances;
    uint256 private constant _TOTAL_SUPPLY = 100 ether;

    // FIX 1: Add a constructor to mint the initial supply to the deployer
    constructor() {
        s_balances[msg.sender] = _TOTAL_SUPPLY;
    }

    function name() public pure returns (string memory) {
        return "Manual Token";
    }

    function totalSupply() public pure returns (uint256) {
        return _TOTAL_SUPPLY;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    // FIX 2 & 3: Make the transfer function safe and standard
    function transfer(address _to, uint256 _value) public returns (bool) {
        // BRANCH 1: You have a test for this (testTransferRevertsIfInsufficientBalance)
        require(balanceOf(msg.sender) >= _value, "ManualToken: Insufficient balance");
        
        uint256 previousBalances = balanceOf(msg.sender) + balanceOf(_to);

        s_balances[msg.sender] -= _value;
        s_balances[_to] += _value;

        // BRANCH 2: THIS IS THE UNTESTED BRANCH!
        // You don't have a test that makes this specific check fail.
        require(balanceOf(msg.sender) + balanceOf(_to) == previousBalances, "ManualToken: Token conservation failed");

        return true;
    }
}
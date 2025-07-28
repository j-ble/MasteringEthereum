// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "../src/interfaces/RebaseToken.I.sol";

contract Vault {
    // We need to pass the token address to the constructor
    // Create a deposit function that mints tokens to the user equal to the amount of ETH deposited
    // Create a redeem function that burns tokens from the user and sends the user ETH
    // Create a way to add rewards to the vault
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error VAULT__REDEEM_FAILED();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    // Able to send rewards to the vault
    receive() external payable{}

    /**
     * @notice Allows users to deposit ETH into the vault and mint rebase tokens to the user
     */
    function deposit() external payable {
        // We need to use the amount of ETH the user sent to mint the rebase token to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their rebase tokens for ETH
     * @param _amount The amount of rebase tokens to redeem 
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn the tokens form the user
        i_rebaseToken.burn(msg.sender, _amount);
        // Send the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert VAULT__REDEEM_FAILED();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the rebase token
     * @return The address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
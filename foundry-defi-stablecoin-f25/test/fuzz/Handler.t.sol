// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @notice This contract acts as the "actor" or "user" in our invariant test setup.
 * The Foundry fuzzer will call the public functions on this contract to interact with
 * the DSCEngine protocol. This handler is specifically designed to achieve ZERO reverts
 * by creating the necessary preconditions (token balance, approvals) "just-in-time" for each call.
 * This ensures the fuzzer spends 100% of its time testing valid protocol states.
 */

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Handler is going to narrow down the way we call functions

contract Handler is Test {
    // --- State Variables ---
    DSCEngine engine;
    DecentralizedStableCoin dsc;

    // Collateral token mocks, cached for easy access
    ERC20Mock weth;
    ERC20Mock wbtc;
    ERC20Mock wxrp;

    // A large but reasonable upper bound for fuzzed inputs to prevent overflow
    // and keep tests within a realistic domain. `type(uint96).max` is a common choice.
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    /**
     * @notice Initializes the handler with the core protocol contracts.
     * @param _dscEngine The main DSCEngine contract.
     * @param _dsc The DecentralizedStableCoin (DSC) token contract.
     */
    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        // Cache the collateral token contract addresses for cheaper and easier access
        // in handler functions.
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wxrp = ERC20Mock(collateralTokens[2]);
    }

    function mintDsc(uint256 amount) public {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(msg.sender);

        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if(maxDscToMint < 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0 ) {
            return;
        }
        vm.startPrank(msg.sender);
        engine.mintDsc(amount);
        vm.stopPrank();        
    }

    /**
     * @notice Models a user depositing collateral into the DSCEngine.
     * @dev This function implements the "On-the-Fly User"/ "Stateless" pattern. For each call,
     * it generates a new "user" (the fuzzer's `msg.sender`), mints the exact
     * amount of collateral needed, and approves the engine. This guarantees that
     * the `depositCollateral` call will never revert due to lack of funds or allowance.
     * @param collateralSeed A random value from the fuzzer to select a collateral type.
     * @param amountCollateral A random value from the fuzzer for the deposit amount.
     */
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // Select a collateral token based on the fuzzer's input.
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // Constrain the fuzzed amount to our defined, reasonable range.
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        // --- The "On-the-Fly User" Pattern ---
        // The fuzzer calls this function from a random, temporary address (`msg.sender`).
        // We use a prank to make this temporary address the actor for the entire sequence.
        vm.startPrank(msg.sender);
        // Mint the exact required amount of tokens directly to the temporary user.
        collateral.mint(msg.sender, amountCollateral);
        // Approve the DSCEngine to spend these newly minted tokens.
        collateral.approve(address(engine), amountCollateral);
        // Call the actual function on the contract under test. This is guaranteed to succeed.
        engine.depositCollateral(address(collateral), amountCollateral);
        // Stop the prank to clean up the testing state.
        vm.stopPrank();
    }

    /**
     * @notice Models a user redeeming their deposited collateral from the DSCEngine.
     * @dev This function models a STATEFUL user interaction, which is critical for
     * testing the full deposit -> redeem lifecycle.
     *
     * Unlike `depositCollateral`, this function does NOT use the "On-the-Fly User"
     * pattern (no `vm.prank` or minting). Instead, it relies on the fuzzer to have
     * built up state in previous steps (i.e., by calling `depositCollateral`).
     *
     * The key to preventing reverts is to query the protocol for the `msg.sender`'s
     * ACTUAL, current collateral balance and then use `bound()` to ensure we only
     * attempt to redeem an amount they legitimately have. This makes the fuzzer
     * highly efficient at testing valid redemption scenarios.
     *
     * @param collateralSeed A random value from the fuzzer to select which collateral to redeem.
     * @param amountCollateral A random value from the fuzzer for the redemption amount.
     */
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        // Select which collateral type to attempt to redeem based on the fuzzer's input.
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // Query the DSCEngine to find the true, current balance of this user (`msg.sender`).
        // This is the absolute maximum they could possibly redeem.
        uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        // Constrain the fuzzer's input to a valid range.
        // The amount must be between 0 and the actual available balance.
        // This is the core technique that prevents reverts from trying to redeem too much.
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        // Call the actual `redeemCollateral` function on the engine.
        // Because of the bounding above, this call is now guaranteed to be valid
        // from the perspective of the user's balance.
        engine.redeemCollateral(address(collateral), amountCollateral);
    }

    // --- Helper Functions ---

    /**
     * @notice Selects a collateral token pseudo-randomly based on a seed.
     * @dev Uses modulo arithmetic to provide a deterministic but distributed choice
     * of collateral for the fuzzer.
     * @param collateralSeed A random number from the fuzzer.
     * @return The ERC20Mock contract instance for the chosen collateral.
     */
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        uint256 remainder = collateralSeed % 3;
        if (remainder == 0) {
            return weth;
        } else if (remainder == 1) {
            return wbtc;
        } else {
            return wxrp;
        }
    }
}
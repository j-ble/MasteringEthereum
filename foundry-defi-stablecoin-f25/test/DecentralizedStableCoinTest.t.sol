// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * This test file is written for foundry ('forge test').
 * The goal is to hit - and assert on - EVERY behavior branch
 * inside the DecentralizedStableCoin.sol, so that 'forge coverage' 
 * reports 100 % statement *and* 100 % branches.
 */

import {Test} from "../lib/forge-std/src/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    /**
     * ------------------------------------------------- *
     * State variables used across the whole test suite
     * ------------------------------------------------- */
    DecentralizedStableCoin private dsc;
    
    // Hardcoding addresses for convenience.
    // Foundry gives initial balance of 100 ether
    address private constant OWNER = address(1); // will deploy contract
    address private constant ALICE = address(2);
    address private constant BOB = address(3);

    uint256 private constant TOKEN = 1e18;

    /* -------- */
    /*  setUp() */
    /* -------- */

    function setUp() public {
        /**
         * We *impersonate* OWNER while deploying so that 'msg.sender'
         * insider the constructor is OWNER.
         * The makes OWNER the 'Ownable' owner and allows us to test the modifier 'onlyOwner'.
         */
        vm.prank(OWNER);
        dsc = new DecentralizedStableCoin();
    }

    /* -------- */
    /*  mint()  */
    /* -------- */

    /**
     * 1. Owner mints 5 DSC to ALICE
     *    We assert on:
     *      - the return value
     *      - ALICE's balance
     *      - totalSupply()
     */
    function testOwnerCanMint() public {
        vm.prank(OWNER);
        bool success = dsc.mint(ALICE, 5 * TOKEN);

        assertTrue(success, "mint() should return true on success");
        assertEq(dsc.balanceOf(ALICE), 5 * TOKEN, "ALICE's balance mismmatch");
        assertEq(dsc.totalSupply(), 5 * TOKEN, "totalSupply() mismmatch");
    }

    /**
     * 2. Revert path - non-owner tries to mint
     *    We do *not* specify the expected selector; 'Ownable' itself reverts
     *    with 'OwnableUnauthorizedAccount(address)' so a generic expectRevert is sufficient.
     */
    function testMint_RevertIfCallerNotOwner() public {
        vm.expectRevert();
        dsc.mint(ALICE, TOKEN);
    }

    /**
     * 3. Revert path - '_to == address(0)'/ zero address
     *    Here we *do* specify the selector of our custom error to guarantee
     *    we are hitting the intended require-check. 
     */
    function testMint_RevertIfToIsZero() public {
        vm.prank(OWNER);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), TOKEN);
    }

    /**
     * 4. Revert path - '_amount <=0' / zero amount
     */
    function testMint_RevertIfAmountIsZero() public {
        vm.prank(OWNER);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(ALICE, 0);
    }

    /* -------- */
    /*  burn()  */
    /* -------- */

    /**
     * 1. Owner mints to itself then burns a portion
     *    We perform all actions in a single 'vm.startPrank / stopPrank'
     *    so 'msg.sender' remains OWNER for both txns.
     */
    function testOwnerCanBurn() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, 10 * TOKEN); // pre-fund
        dsc.burn(5 * TOKEN); // burns 5 tokens
        vm.stopPrank();

        assertEq(dsc.balanceOf(OWNER), 5 * TOKEN);
        assertEq(dsc.totalSupply(), 5 * TOKEN);
    }

    /**
     * 2. Revert path - non-owner tries to burn
     *    First give BOB a toekn so we *know* we are reverting due to
     *    'onlyOwner', *not* due to balance/amount checks.
     */
    function testBurn_RevertIfCallerNotOwner() public {
        vm.prank(OWNER);
        dsc.mint(BOB, TOKEN);

        vm.prank(BOB);
        vm.expectRevert();
        dsc.burn(TOKEN);
    }

    /**
     * 3. Revert path - '_amount == 0' / zero amount
     */
    function testBurn_RevertIfAmountIsZero() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, TOKEN);

        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
        vm.stopPrank();
    }

    /**
     * 4. Revert path - '_amount' larger than balance
     */
    function testBurn_RevertIfAmountExceedsBalance() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, TOKEN);

        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(TOKEN + 1); // attempt to burn > balance
        vm.stopPrank();
    }

    /* --------------- */
    /*  name / symbol  */
    /* --------------- */

    /**
     * Sanity check - confirm ERC20 metadata
     */
    function testNameAndSymbol() public view {
        assertEq(dsc.name(), "DecentralizedStableCoin");
        assertEq(dsc.symbol(), "DSC");
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "@forge/console.sol";

// Base contract
contract A {
    function doSomething() public virtual {
        console.log("A is doing something.");
    }
}

// First intermediate parent
contract B is A {
    function doSomething() public virtual override {
        console.log("B is preparing...");
        super.doSomething(); // Calls A.doSomething()
        console.log("B is finished.");
    }
}

// Second intermediate parent
contract C is A {
    function doSomething() public virtual override {
        console.log("C is preparing...");
        super.doSomething(); // Also calls A.doSomething()
        console.log("C is finished.");
    }
}

/**
 * @notice The order here `is B, C` is the critical factor.
 * The MRO (Method Resolution Order) will be: [D, C, B, A]
 * It prioritizes parents from right to left.
 */
contract D is B, C {
    // We must specify both parents in the override since both have a `doSomething` function.
    function doSomething() public override(B, C) {
        console.log("D is starting...");
        // This `super` call will invoke the next function in the MRO after D, which is C.
        super.doSomething();
        console.log("D has finished.");
    }
}

/**
 * @notice The order here `is C, B` is reversed.
 * The MRO will now be: [E, B, C, A]
 */
contract E is C, B {
    function doSomething() public override(C, B) {
        console.log("E is starting...");
        // This `super` call will invoke the next function in the MRO after E, which is B.
        super.doSomething();
        console.log("E has finished.");
    }
}
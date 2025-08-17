// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ValueTypeAssignmentExample {

    /**
     * @notice Demonstrates that assigning a value type (uint256) creates an independent copy.
     * @return originalValue The initial value, which remains unchanged.
     * @return copiedValue The new value after modification, showing it is a separate variable.
     */
    function demonstrateAssignment() public pure returns (uint256 originalValue, uint256 copiedValue) {
        // 1. A uint256 (a value type) is created in memory with the value 100.
        originalValue = 100;

        // 2. The value of `originalValue` (100) is read, and a brand new,
        //    separate variable `copiedValue` is created in memory with that copied value.
        //    There is no link between them.
        copiedValue = originalValue;

        // 3. We now modify ONLY the copied variable. This operation has no effect
        //    on the memory location holding `originalValue`.
        copiedValue = 999;

        // 4. We return both values. They will be different, proving they are
        //    independent copies. The function will return (100, 999).
        return (originalValue, copiedValue);
    }
}
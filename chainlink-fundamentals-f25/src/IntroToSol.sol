// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// These are permanently stored on the blockchain in storage:
contract StorageExample {
    uint256 public myNumber = 42;    // A number
    string public myText = "Hello";  // Text
    bool public isActive = true;     // A true/false value
    address public owner;            // An Ethereum address
    uint256 private secretNumber;    // A private number

    uint256 public counter = 0; // Creates a counter() function that returns the value
    uint256 private password = 123456; // Not accessible from other contracts
    uint256 internal sharedSecret = 42; // Visible to this contract and child contracts
}

contract TokenContract {
    // Must be assigned at declaration
    uint256 public constant DECIMAL_PLACES = 18;
    string public constant TOKEN_NAME = "My Token";
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Declared but not assigned yet
    address public immutable deployer;
    uint256 public immutable deploymentTime;
    
    constructor() {
        // Assigned once in the constructor
        deployer = msg.sender; // Sets the contract creator as the owner
        deploymentTime = block.timestamp;
    }

    // struct: Custom groupings of related data.
    struct Person {
        string name;
        uint256 age;
        address walletAddress;
    }

    // bytes (Dynamic Size): Variable length byte array
    bytes public dynamicData;
}

contract PointerExample {
    // State array in storage
    uint256[] public storageArray = [1, 2, 3];
        
    function manipulateArray() public {
        // This creates a pointer to the storage array
        uint256[] storage storageArrayPointer = storageArray;
            
        // This modifies the actual storage array through the pointer
        storageArrayPointer[0] = 100;
            
        // At this point, storageArray is now [100, 2, 3]
            
        // This creates a copy in memory, not a pointer to storage
        uint256[] memory memoryArray = storageArray;
            
        // This modifies only the memory copy, not the storage array
        memoryArray[1] = 200;
            
        // At this point, storageArray is still [100, 2, 3]
        // and memoryArray is [100, 200, 3]
    }

    // State variable - stored in storage
    uint256[] permanentArray;
    function processArray(uint256[] calldata inputValues) external {
        // 'inputValues' exists in calldata - can't be modified
            
        // Local variable in memory - temporary copy
        uint256[] memory tempArray = new uint256[](inputValues.length);
        for (uint i = 0; i < inputValues.length; i++) {
            tempArray[i] = inputValues[i] * 2;
        }
            
        // Reference to storage - changes will persist
        uint256[] storage myStorageArray = permanentArray;
        myStorageArray.push(tempArray[0]); // This updates the blockchain state
    }
}

contract Counter {
    uint256 public count = 0;
    
    // This function increases the count by 1
    function increment() public {
        count = count + 1;  // You can also write: count += 1;
    }
    
    // This function decreases the count by 1
    function decrement() public {
        count = count - 1;  // You can also write: count -= 1;
    }

    // view: Can read but not modify state
    function getCount() public view returns (uint256) {
        return count;
    }

    // pure: Cannot read or modify state
    function addNumbers(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
}

// Transaction Contract Variables
contract OwnerExample {
    address public owner;
    
    constructor() {
        owner = msg.sender; // The address that deploys the contract becomes the owner
    }
}

contract PaymentExample {
    mapping(address => uint256) public payments;
    
    // Function that can receive ETH
    function makePayment() public payable {
        require(msg.value > 0, "Must send some ETH");
        payments[msg.sender] += msg.value;
    }
    
    // Function that checks if minimum payment was made
    function verifyMinimumPayment(uint256 minimumAmount) public view returns (bool) {
        return payments[msg.sender] >= minimumAmount;
    }
}
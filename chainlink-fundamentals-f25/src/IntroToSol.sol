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

contract DataExample {
    bytes public lastCallData;
    
    // Store the raw calldata of the latest transaction
    function recordCallData() public {
        lastCallData = msg.data;
    }
    
    // View the size of the calldata
    function getCallDataSize() public view returns (uint256) {
        return lastCallData.length;
    }
}

contract TimestampExample {
    uint256 public contractCreationTime;
    
    constructor() {
        contractCreationTime = block.timestamp;
    }
    
    // Check if a specified duration has passed since contract creation
    function hasDurationPassed(uint256 durationInSeconds) public view returns (bool) {
        return (block.timestamp >= contractCreationTime + durationInSeconds);
    }
    
    // Create a simple time lock that releases after a specified date
    function isTimeLockExpired(uint256 releaseTime) public view returns (bool) {
        return block.timestamp >= releaseTime;
    }
}

contract BlockNumberExample {
    uint256 public deploymentBlockNumber;
    
    constructor() {
        deploymentBlockNumber = block.number;
    }
    
    // Calculate how many blocks have been mined since deployment
    function getBlocksPassed() public view returns (uint256) {
        return block.number - deploymentBlockNumber;
    }
    
    // Check if enough blocks have passed for a specific action
    function hasReachedBlockThreshold(uint256 blockThreshold) public view returns (bool) {
        return getBlocksPassed() >= blockThreshold;
    }
}

// Combining Context Variables in a Contract
contract TimeLockedWallet {
    address public owner; // withdrawaling privileges
    uint256 public unlockTime; // enforces the time-lock
    
    // off-chain infustructure
    // track the contract's activity without having to constantly query its state
    event Deposit(address indexed sender, uint256 amount, uint256 timestamp);
    event Withdrawal(uint256 amount, uint256 timestamp);
    
    constructor(uint256 _unlockDuration) {
        owner = msg.sender;
        unlockTime = block.timestamp + _unlockDuration;
    }
    
    // Accept deposits from anyone
    function deposit() public payable {
        require(msg.value > 0, "Must deposit some ETH");
        emit Deposit(msg.sender, msg.value, block.timestamp);
    }
    
    // Only allow the owner to withdraw after the unlock time
    function withdraw() public {
        require(msg.sender == owner, "You are not the owner");
        require(block.timestamp >= unlockTime, "Funds are still locked");
        // Prevents the owner from making a useless, gas-wasting call if the contract is empty
        require(address(this).balance > 0, "No funds to withdraw");
        
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
        
        emit Withdrawal(balance, block.timestamp);
    }
    
    // Check if withdrawal is possible yet
    function withdrawalStatus() public view returns (bool canWithdraw, uint256 remainingTime) {
        if (block.timestamp >= unlockTime) {
            return (true, 0);
        } else {
            return (false, unlockTime - block.timestamp);
        }
    }
}
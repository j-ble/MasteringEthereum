// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample raffle smart contract
 * @author Jacob Blemaster
 * @notice This contract is for creating a sample raffle smart contract
 * @dev Implements Chianlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 players, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0 - Open
        CALCULATING // 1 - Closed
    }
    
    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the raffle in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // RaffleState(0);
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev this is the function that the Chainlink nodes will call to see
     * if the lotery is ready to have a winner picked 
     * The following should be true in order for the upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicityly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpKeep(bytes memory /* checkData */) 
        public
        view 
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // Condition 1: time passed
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        // Condition 2: state
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        // Condition 3: Balance
        bool hasBalance = (address(this).balance > 0);
        // Condition 4: Players
        bool hasPlayers = (s_players.length > 0);
        // The final result: all conditions must be true
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 3. Automatically be called
    function performUpkeep(bytes calldata /* performData */) external {
        // check if enough time has passed
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        // Get our random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest(
            {
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            }
        );        
        s_vrfCoordinator.requestRandomWords(request);
    }

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override { 
        // Checks

        // s_players = 10
        // rng = 12
        // 12 % 10 = 2 <- winner
        
        // Effect (Internal Contract State Changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contracts Interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
            // revert("Failed to send Ether");
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}

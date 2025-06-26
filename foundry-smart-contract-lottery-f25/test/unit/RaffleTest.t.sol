// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER);
        // act / assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // arrange
        vm.prank(PLAYER);
        // act 
        raffle.enterRaffle{value: entranceFee}();
        // assert
        address playerRecorded = raffle.getPlayer(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // arrange
        vm.prank(PLAYER);
        // act 
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // assert
    }

    function testDontAllowPlayersToEnterRaffleWhileRaffleIsCalculating() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // act / assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
    
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }
    // Challenge 1: 
    // testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed
    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act 
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert (!upkeepNeeded);
    } 

    // Challenge 1: 
    function testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed() public {
        // arrange
        // Make isOpen=true, hasBalance=true, & hasPlayers=true
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Make timeHasPassed=false by not waiting the full interval
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        // act
        // timeHasPassed -> false
        // isOpen -> true
        // hasBalance -> true
        // hasPlayers -> true
        // upkeepNeeded = false && true && true && true  -> which is false
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // assert
        assert(!upkeepNeeded);
    }
    // testCheckUpKeepReturnsTrueWhenParametersAreGood
    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // arrange
        // Make isOpen=true, hasBalance=true, & hasPlayers=true
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Make timeHasPassed=true by waiting the full interval
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // act
        // timeHasPassed -> true
        // isOpen -> true
        // hasBalance -> true
        // hasPlayers -> true
        // upkeepNeeded = true && true && true && true  -> which is true
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // assert
        assert(upkeepNeeded);
    }

    /** PERFORM UPKEEP TESTS **/
    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // act / assert
        raffle.performUpkeep("");
    }
    
    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // act / assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered{
        // arrange
        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /** FULFILLRANDOMWORDS **/ 
    function testFullFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // arrange / act / assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

}
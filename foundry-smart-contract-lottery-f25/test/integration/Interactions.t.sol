// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// uint 
// integrations
// forked
// staging <- run tests on mainnet or testnet

// fuzzing
// stateful fuzz
// stateless fuzz
// formal verification

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {SubscriptionAPI} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";


// This contract will hold tests for various scripts
contract InteractionsTest is Test, CodeConstants {
    // This test ensures the `run()` function of the deployment script executes
    function testDeployRaffleScriptRuns() public {
        // arrange
        DeployRaffle deployer = new DeployRaffle();
        // act
        Raffle raffle = deployer.run();
        // assert
        assertNotEq(address(raffle), address(0));
        // If the deployment was successful, the address will not be the zero address
    }

    function testHelperConfigReturnsCachedAnvilConfig() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();
        // Act
        HelperConfig.NetworkConfig memory config1 = helperConfig.getConfig();
        HelperConfig.NetworkConfig memory config2 = helperConfig.getConfig();
        // Assert 
        assertEq(config1.vrfCoordinator, config2.vrfCoordinator);
    }

    function testHelperConfigReturnsSepoliaConfig() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);   // Cheatcode to trick the EVM into thinking we are on Sepolia
        // Act
        HelperConfig.NetworkConfig memory sepoliaConfig = helperConfig.getConfig();
        // Assert
        // Verify that we actually got the Sepolia config by checking the known VRF coordinator address
        assertEq(sepoliaConfig.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    }

    function testHelperConfigRevertsOnInvalidChainId() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();
        uint256 invalidChainId = 123456789;
        vm.chainId(invalidChainId);
        // Act / Assert
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        helperConfig.getConfig();
    }

    function testGetConfigByChainId() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();
        // Act
        HelperConfig.NetworkConfig memory localConfig = helperConfig.getConfigByChainId(LOCAL_CHAIN_ID);
        // Assert
        assertEq(localConfig.entranceFee, 0.01 ether);
    }

    function testGetSepoliaEthConfig() public {
        // Arrange
        HelperConfig helperConfig = new HelperConfig();
        // Act
        HelperConfig.NetworkConfig memory sepoliaConfig = helperConfig.getSepoliaEthConfig();
        // Assert
        assertEq(sepoliaConfig.interval, 30);
    }

    function testCreateSubsscriptionScript() public {
        // arrange
        CreateSubscription createSubscription = new CreateSubscription();
        // act / assert 
        // The run() function should execute without reverting
        // Creates a subscription using the mock coordinator deployed by HelperConfig
        createSubscription.run();
    }

    function testFundSubscriptionElseBranch() public {
        // arrange
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        FundSubscription funder = new FundSubscription();
        LinkToken linkToken = new LinkToken();
        address mockVrfCoordinator = address(this);
        uint256 mockSubId = 123;
        address fundingAccount = makeAddr("funder");
        linkToken.mint(fundingAccount, funder.FUND_AMOUNT());

        // Act
        // We prank as the funding account and call the function with our mocks
        funder.fundSubscription(mockVrfCoordinator, mockSubId, address(linkToken), fundingAccount);

        // assert
        // Verify the LINK was transferred from the account
        assertEq(linkToken.balanceOf(fundingAccount), 0);
    }

    function testAddConsumerUsingConfigRevertsWithInvalidSubscription() public {
        // arrange
        DeployRaffle deployer = new DeployRaffle();
        Raffle raffle = deployer.run();
        AddConsumer consumerAdder = new AddConsumer();

        // act / assert
        vm.expectRevert(SubscriptionAPI.InvalidSubscription.selector);
        consumerAdder.addConsumerUsingConfig(address(raffle));
    }

    // This function is required by the ERC677 (LINK) standard's `transferAndCall`
    // It's called by the LINK token after a successful transfer to a contract
    // Our test contract is acting as the mock recipient, so it needs this function
    function onTokenTransfer(address, uint256, bytes calldata) external pure returns (bool) {
        return true;
    }

    function testFundSubscriptionScriptRuns() public {
        // arrange
        FundSubscription funder = new FundSubscription();
        // act / assert
        vm.expectRevert(SubscriptionAPI.InvalidSubscription.selector);
        funder.run();
    }

    function testFundSubscriptionUsingConfig() public {
        FundSubscription funder = new FundSubscription();
        vm.expectRevert(SubscriptionAPI.InvalidSubscription.selector);
        funder.fundSubscriptionUsingConfig();
    }
}


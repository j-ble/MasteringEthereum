// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {RateLimiter} from "@chainlink-ccip/libraries/RateLimiter.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@forge/interfaces/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink-ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@chainlink-ccip/pools/TokenPool.sol";

contract CrossChainTest is Test {
    address owner = makeAddr("owner");
    address user = makeAddr("user");
    uint256 SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork private ccipLocalSimulatorFork;

    RebaseToken private sepoliaToken;
    RebaseToken private arbSepoliaToken;

    Vault private vault;

    RebaseTokenPool private sepoliaPool;
    RebaseTokenPool private arbSepoliaPool;

    Register.NetworkDetails private sepoliaNetworkDetails;
    Register.NetworkDetails private arbSepoliaNetworkDetails;

    // State variables to pass data between fork contexts
    bytes32 public messageId;
    uint256 public localUserInterestRate;

    function setUp() public {
        // create two forks
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 1. Deploy and configure on Sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            sepoliaToken.decimals(),
            new address[](0), 
            sepoliaNetworkDetails.rmnProxyAddress, 
            sepoliaNetworkDetails.routerAddress
        );
        vault = new Vault(IRebaseToken(address(sepoliaToken)));

        // Make contracts persistent so they exist on the other fork
        vm.makePersistent(address(sepoliaToken));
        vm.makePersistent(address(sepoliaPool));
        vm.makePersistent(address(vault));

        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // 2. Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        // Call setUp on the simulator for the Arbitrum Sepolia fork
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            arbSepoliaToken.decimals(),
            new address[](0), 
            arbSepoliaNetworkDetails.rmnProxyAddress, 
            arbSepoliaNetworkDetails.routerAddress
        );

        // Make contracts persistent
        vm.makePersistent(address(arbSepoliaToken));
        vm.makePersistent(address(arbSepoliaPool));

        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );
        vm.stopPrank();

        // 3. Configure pools to recognize each other
        configureTokenPool(
            sepoliaFork, 
            address(sepoliaPool), 
            arbSepoliaNetworkDetails.chainSelector, 
            address(arbSepoliaPool), 
            address(arbSepoliaToken)
        ); 
        configureTokenPool(
            arbSepoliaFork, 
            address(arbSepoliaPool), 
            sepoliaNetworkDetails.chainSelector, 
            address(sepoliaPool), 
            address(sepoliaToken)
        ); 
    }

    function configureTokenPool(
        uint256 fork, 
        address localPool,
        uint64 remoteChainSelector, 
        address remotePool, 
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.prank(owner);

        // The remotePoolAddress needs to be in an array
        bytes[] memory remotePools = new bytes[](1);
        remotePools[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);

        // struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        // }

        // Construct the struct with the correct fields
        // Removed "allowed: true" and used "remotePoolAddresses: remotePools"
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePools,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });
        // Call the function with the correct number of arguments
        TokenPool(localPool).applyChainUpdates(new uint64[](0),chainsToAdd);
    }

    function bridgeTokens(
        uint256 amountToBridge, 
        uint256 localFork, 
        uint256 remoteFork, 
        Register.NetworkDetails memory localNetworkDetails, 
        Register.NetworkDetails memory remoteNetworkDetails, 
        RebaseToken localToken, 
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        // }
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 100_000}))
        });
        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        
        vm.warp(block.timestamp + 20 minutes);
        vm.selectFork(localFork);
        
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }

    function testBridgeAllTokens() public {
        // 1. Setup and send from Sepolia (source fork)
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);

        // 2. Prepare and send the CCIP message from Sepolia
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(sepoliaToken),
            amount: SEND_VALUE
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: sepoliaNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 100_000}))
        });
        uint256 fee =
            IRouterClient(sepoliaNetworkDetails.routerAddress).getFee(arbSepoliaNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(sepoliaNetworkDetails.linkAddress).approve(sepoliaNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(sepoliaToken)).approve(sepoliaNetworkDetails.routerAddress, SEND_VALUE);
        
        uint256 localBalanceBefore = sepoliaToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(sepoliaNetworkDetails.routerAddress).ccipSend(arbSepoliaNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = sepoliaToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - SEND_VALUE);
        localUserInterestRate = sepoliaToken.getUserInterestRate(user);

        // 3. Get state on Arbitrum Sepolia (destination fork) BEFORE message delivery
        vm.selectFork(arbSepoliaFork);
        uint256 remoteBalanceBefore = arbSepoliaToken.balanceOf(user);

        // 4. Go back to the source fork to run the simulator.
        //    It will handle switching back to the destination fork internally.
        vm.selectFork(sepoliaFork);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork);

        // 5. Assert the final state on Arbitrum Sepolia.
        //    The active fork is now arbSepoliaFork.
        vm.warp(block.timestamp + 20 minutes);
        uint256 remoteBalanceAfter = arbSepoliaToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + SEND_VALUE);
        uint256 remoteUserInterestRate = arbSepoliaToken.getUserInterestRate(user);
        assertEq(remoteUserInterestRate, localUserInterestRate);
    }
}
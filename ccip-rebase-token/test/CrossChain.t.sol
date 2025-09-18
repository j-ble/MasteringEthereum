//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "../lib/forge-std/src/Test.sol";

import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {RateLimiter} from "@chainlink-ccip/libraries/RateLimiter.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@chainlink-ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@chainlink-ccip/pools/TokenPool.sol";

contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address user = makeAddr("user");
    uint256 public SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;

    // // State variables to pass data between fork contexts
    // bytes32 public messageId;
    // uint256 public localUserInterestRate;

    function setUp() public {
        address[] memory allowlist = new address[](0);
        // create two forks
        // 1. Set up the Sepolia and arb forks
        sepoliaFork = vm.createSelectFork("eth-sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // 2. Deploy and configure on Sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        console.log("source rebase token address");
        console.log("address"(arbSepoliaToken));
        console.log("Deploying token pool on Sepolia");
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            allowlist,
            sepoliaNetworkDetails.rmnProxyAddress, 
            sepoliaNetworkDetails.routerAddress
        );
        // deploy the vault
        vault = new Vault(IRebaseToken(address(arbSepoliaToken)));
        // add rewards to the vault
        vm.deal(address(vault), 1e18);
        // Set pool on the token contract for permissions on Sepolia
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        arbSepoliaToken.grantMintAndBurnRole(address(vault));
        // claim role on Sepolia
        registryModuleOwnerCustomSepolia = 
            RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(arbSepoliaToken));
        // accept role on Sepolia
        tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistrySepolia.acceptAdminRole(address(arbSepoliaToken));
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();

        // 3. Deploy and configure on destination chain
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        console.log("deploying arb sepolia token");
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        sepoliaToken = new RebaseToken();
        console.log("sepolia token address");
        console.log(address(sepoliaToken));
        // Deploy the token pool on arb sepolia
        console.log("Deploying token pool on Arbitrum Sepolia");
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            allowlist,
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        // Set pool on the token contract for permissions on Arbitrum
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        // Claim role on Arbitrum
        registryModuleOwnerCustomarbSepolia =
            RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(address(sepoliaToken));
        // Accept role on Arbitrum
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(sepoliaToken));
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryarbSepolia.setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 fork,
        TokenPool localPool,
        TokenPool remotePool,
        IRebaseToken remoteToken,
        Register.NetworkDetails memory remoteNetworkDetails
    ) public {
        vm.selectFork(fork);
        vm.startPrank(owner);
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(address(remotePool));
        chains[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteNetworkDetails.chainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(address(remoteToken)),
            outboundRateLimiterConfig: RateLimiter.Config(
                {isEnabled: 
                    false, 
                    capacity: 0, 
                    rate: 0
                }),
            inboundRateLimiterConfig: RateLimiter.Config(
                {isEnabled:
                    false, 
                    capacity: 0, 
                    rate: 0
                })
        });
        uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
        localPool.applyChainUpdates(remoteChainSelectorsToRemove, chains);
        vm.stopPrank();
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
        vm.startPrank(user);
        // struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        // }
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = 
            Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
        tokenToSendDetails[0] = tokenAmount;
        // Approve the router to burn tokens on users behalf
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // we need to encode the address to bytes
            data: "", // We don't need any data for this example
            tokenAmounts: tokenToSendDetails, // this needs to be of type EVMTokenAmount[] as you could send multiple tokens
            feeToken: localNetworkDetails.linkAddress, // The token used to pay for fee
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 100_000}))
        });
        vm.stopPrank();
        // Give the user the fee amount of LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            user, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        );

        vm.startPrank(user);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        ); // Approve the fee
        // log the values before bridging
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(user);
        console.log("Local balance before bridge: %d", balanceBeforeBridge);

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message); // Send the message
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken)).balanceOf(user);
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge);
        assertEq(sourceBalanceAfterBridge, balanceBeforeBridge - amountToBridge);
        vm.stopPrank();

        vm.selectFork(remoteFork);
        // Pretend it takes 15 minutes to bridge the tokens
        vm.warp(block.timestamp + 900);
        // get initial balance on Arbitrum
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(user);
        console.log("Remote balance before bridge: %d", initialArbBalance);
        vm.selectFork(localFork); // assumes you are currently on the local fork before calling switchChainAndRouteMessage
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        conosle.log("Remote user intereste rate: %d", remoteToken.getUserInterestRate(user));
        uint256 sepoliaBalance = IERC20(address(remoteToken)).balanceOf(user);
        console.log("Sepolia balance before bridge: %d", sepoliaBalance);
        assertEq(sepoliaBalance, initialArbBalance + amountToBridge);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        uint256 startBalance = IERC20(address(sepoliaToken)).balanceOf(user);
        assertEq(startBalance, SEND_VALUE);
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );
    }
}
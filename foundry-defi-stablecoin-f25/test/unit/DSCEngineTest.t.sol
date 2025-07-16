// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployDSC} from "../../src/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../src/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address xrpUsdPriceFeed;
    address weth;
    
    address public USER = makeAddr("user"); 
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    /////////////////////
    //      Modifier   // 
    /////////////////////
    /**
     * @dev Make setting up tests easier by adding a modifier to the test contract
     */
    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        // User deposits 10 wETH as collateral (worth $20,000) and mint $5,000 DSC
        // Health Factor should be high. (20000 * 50 / 100) / 5000 = 2.
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 5000 ether);
        vm.stopPrank(); 
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed,xrpUsdPriceFeed, weth,,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////////////////
    // Contructor Test //
    /////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public{
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ///////////////////
    // Price Testing //
    ///////////////////
    function testCanDepositAndMint() public depositedCollateralAndMintedDsc {
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 5000 ether);
    }

    function testRevertIfMintBreaksHealthFactor() public {
        // This is the test setup from before, now self-contained in the function
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // Now for the minting part that should fail
        uint256 amountToMint = 10001 ether; // Attempting to mint $10,001
        // 1. Manually calculate the exact health factor the contract will compute
        //    before it reverts. This makes the test robust and avoids "floating numbers".
        uint256 expectedHealthFactor;
        // We can make this an external view function for easier testing or just recalculate here
        {
            (, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
            uint256 collateralAdjustedForThreshold = (collateralValueInUsd * engine.getLiquidationThreshold()) / engine.getLiquidationPrecision();
            expectedHealthFactor = (collateralAdjustedForThreshold * engine.getPrecision()) / amountToMint;
        }
        // The error log told said value is 999900009999000099. Our calculation confirms it.
        // 2. Use `abi.encodeWithSelector` to create the exact revert data.
        bytes memory expectedRevertData = abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor);

        // 3. Tell the VM to expect this exact data.
        vm.expectRevert(expectedRevertData);

        // 4. Run the function that is expected to revert.
        vm.startPrank(USER);
        engine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2,000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 25e18 * 2000/ETH = 30,000e18 
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    //////////////////////////////
    // Deposit Collateral Tests //
    //////////////////////////////
    function testCollateralDeposited() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;      
    }
    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral{
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueInUsd = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(expectedTotalDscMinted, totalDscMinted);
        assertEq(expectedCollateralValueInUsd, AMOUNT_COLLATERAL);
    }

    ////////////////////////////////////////
    // Redeem Collateral & Burn DSC Tests //
    ////////////////////////////////////////
    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        // We start with 5000 DSC minted. Let's burn it all.
        uint256 amountToBurn = 5000 ether;

        // The user must approve the engine to pull their DSC
        vm.startPrank(USER);
        dsc.approve(address(engine), amountToBurn);
        engine.burnDsc(amountToBurn);
        vm.stopPrank();

        // Check that the user's DSC debt is now 0
        (uint256 userDscMinted, ) = engine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }

    function testCanRedeemCollateral() public depositedCollateral {
        // We start with 10 WETH deposited and 0 DSC minted.
        // We should be able to redeem it all.
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        
        // Check that the user got their WETH back
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, STARTING_ERC20_BALANCE);
    }

    // This is the counterpart to the test we just fixed!
    function testRevertIfRedeemBreaksHealthFactor() public depositedCollateralAndMintedDsc {
        // Current State: 10 WETH ($20k) collateral, 5k DSC debt. HF = 2.
        // Action: Try to redeem 6 WETH ($12k).
        // Expected Future State: 4 WETH ($8k) collateral, 5k DSC debt.
        // This is unhealthy. HF would be 0.8.
        uint256 amountToRedeem = 6 ether; // Redeeming $12k of the $20k collateral

        // New collateral value would be 4 WETH = $8,000.
        // Adjusted value = $8,000 * 50% = $4,000.
        // With $5,000 debt, the Health Factor would be 0.8, which is < 1. This must revert.
        
        // 1. Calculate the expected health factor AFTER the flawed redemption.
        // Since this is a test, we can directly manipulate the expected values.
        uint256 expectedCollateralValueInUsd = engine.getUsdValue(weth, AMOUNT_COLLATERAL - amountToRedeem);
        uint256 collateralAdjustedForThreshold = (expectedCollateralValueInUsd * engine.getLiquidationThreshold()) / engine.getLiquidationPrecision();
        
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        uint256 expectedHealthFactor = (collateralAdjustedForThreshold * engine.getPrecision()) / totalDscMinted;

        // 2. Build the exact revert data payload.
        bytes memory expectedRevertData =
            abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor);

        // 3. Tell the VM to expect this exact data.
        vm.expectRevert(expectedRevertData);
        
        // In your DSCEngine.sol, the _revertIfHealthFactorIsBroken in redeemCollateral does NOT pass the value.
        // If it DID, we would use the abi.encodeWithSelector pattern again.
        vm.startPrank(USER);
        engine.redeemCollateral(weth, amountToRedeem);
        vm.stopPrank();
    }

    // This test covers the combined function
    function testCanRedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        uint256 amountToBurn = 5000 ether;
        uint256 amountToRedeem = AMOUNT_COLLATERAL;

        vm.startPrank(USER);
        dsc.approve(address(engine), amountToBurn);
        engine.redeemCollateralForDsc(weth, amountToRedeem, 0, amountToBurn);
        vm.stopPrank();

        // Check that both balances are correct
        (uint256 userDscMinted, ) = engine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
        
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, STARTING_ERC20_BALANCE);
    }
}
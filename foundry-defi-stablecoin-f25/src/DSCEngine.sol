// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Jacob Blemaster
 * 
 * The system is designed to be as minimal as possible,
 * and have the tokens maintain a 1 token == $1 peg.
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 * 
 * It is similar to DAI if DAI had no governance, no fees, 
 * and was only backed by wETH, wBTC, and wXRP. 
 * 
 * Our DSC system should always be "overcollateralized". At no point, should the value of 
 * all collateral <= the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the DSC system. It handles all the logic for mining and redeeming DSC,
 * as well as depositing & withdrawing collateral. 
 * @notice This contract is VERY loosely based on the Sky project in which Dai generates Single-Collateral Dai (SDC), or Sai. 
 */
contract DSCEngine is ReentrancyGuard{
    /////////////////////////
    //      Errors         //
    /////////////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintingDscFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    //////////////////////////////////
    //      State Variables         //
    //////////////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18; 
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; 
    uint256 private constant LIQUIDATION_BONUS = 10; // This means a 10% bonus

    /** 
     * s_priceFeeds maps a collateral token address to a USD price feed oracle (Chainlink).
     * If a token is *not* present in this mapping, it is treated as "not allowed".
     * 
     * e.g. 0xC02... (wETH) -> 0x5f... (ETH / USD Chianlink Aggregator)
     */
    mapping(address token => address priceFeed) private s_priceFeeds;

    /**
     * Nested mapping that tracks how much collateral every user has deposited
     * for every whitelisted token.
     */
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    // Minting Debt
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    /**
     * Reference to the immutable DSC token. Immutable saves gas on each 
     * access compared to a regular storage variable. 
     */
    DecentralizedStableCoin private immutable i_dsc;

    /////////////////////////
    //      Events       //
    /////////////////////////
    // Emitting granular events makes it easy for off-chain indexers/dApps to
    // reconstruct protocol state. 
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexedredeemedTo, address indexed token, uint256 amount);

    /////////////////////////
    //      Modifers       //
    /////////////////////////

    /**
     * @dev Reverts if `amount` is zero. This is used as a general sanity check
     *      because e.g. an ERC20 `transferFrom()` of 0 tokens is a valid call
     *      that will not revert on its own.
     */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    /**
     * @dev Ensures the collateral token is part of the allowed set.
     *      Implementation detail: We store the priceFeeds[token] and rely on
     *      "zero-address -> not allowed". Therefore, checking if the value is
     *      zero tells us whether the token is unsupported.
     */
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    ///////////////////////////////////////
    //      Functions - Constructor      //
    ///////////////////////////////////////

    /**
     * @notice Deploys DSCEngine and wires token -> priceFeed mappings.
     * @param tokenAddresses     Array of collateral token addresses (wETH, wBTC, wXRP)
     * @param priceFeedAddresses Array of corresponding Chainlink aggregator
     *                           addresses returning *USD price with 8 decimals*.
     * @param dscAddress         Address of the **already deployed** 
     *                           DecentralizedStableCoin contract.
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feeds
        // 1. Sanity check: arrays must be same length
        if(tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // 2. Populate token->priceFeed mapping. We purposely do not check for
        //    duplicates-the last entry "wins". Because constructor executes
        //    once, this is a non-issue.
        for(uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        // 3. Save immutable reference to DSC token contract.
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ////////////////////////////////////////////////////       
    //      External (state-changing) Functions       //
    ////////////////////////////////////////////////////
    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DSC to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice Implements the "Deposit" leg of the system.
     * @dev    The function follows CEI (Check, Effects, Interact):
     *         1. Checks - performed by the `moreThanZero()` and `isAllowedToken()` modifiers
     *         2. Effects - update protocol accounting *before* the external token
     *                      transfer to guard against reentrancy.
     *         3. Interact - call ERC20 `transferFrom`.
     * @param tokenCollateralAddress ERC20 address of the token to deposit as collateral.
     * @param amountCollateral       The amount (in native token) of collateral to deposit.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) 
        public 
        // Checks
        isAllowedToken(tokenCollateralAddress) 
        moreThanZero(amountCollateral) 
        nonReentrant    // <-- Inherited from ReentrancyGuard
    {
        // Effects
        // Accure deposited balance *before* external interaction
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;

        // Emit event so UIs can update optimistically.
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);

        // Interact
        // Pull token from user -> engine. We rely on the user having already
        // executed `IERC20.approve(engine, amount)` or and "infinite" approval.
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @param tokenCollateralAddress The collateral address to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of DSC to burn
     * This function burns DSC and redeems underlying collateral in one transaction
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256, uint256 amountDscToBurn) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // redeemCollateral already check health factor
    }

    // Example of value of collateral dropping to much:
    // $2000 ETH -> $400 ETH
    // $500 DSC -> Liquidated
    // Example of setting a %150 threshold:
    // $2000 ETH -> MUST HAVE $750 ETH 
    // $500 DSC

    // In order to redeem collateral:
    // 1. health factor must be > 1 AFTER collateral pulled
    // DRY: Don't Repeat Yourself
    // CEI: Check, Effects, Interact
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant {
        // 100 - 1000 (revert)
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // check if collateral value > DSC amount
    /**
    * @notice follows CEI (Check, Effects, Interact):
    * @param amountDscToMint The amount of decentralized stable coin to mint.
    * @notice they must have more collateral value than the minimum threshold.
    */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant{
        // Keep track of how much DSC they minted
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted to much, revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted) {
            revert DSCEngine__MintingDscFailed();
        }
    }

    // Do we need to check if this breaks health factor?
    function burnDsc(uint256 amount) public moreThanZero(amount) nonReentrant {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I do not think this would ever hit...
    }

    // If we do start nearing undercollateralization, we need someone to liquidate positions

    // $100 ETH backing $50 DSC
    // $20 ETH back $50 DSC <- DSC isn't worth $1!!!

    // $75 backing $50 DSC
    // Liquidator take $75 backing and burns off the $50 DSC

    // If someone is almost undercollateralized, we will pay you to liquidate them!

    /**
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor must be below
     *             the MIN_HEALTH_FACTOR.
     * @param debtToCover The amount of DSC you want to burn to improve the users health factor.
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the user funds
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized
     *         in order for this to work.
     * @notice A known bug would be if the protocol were 100% or less collateralized, then
     *         we wouldn't be able to incentivize the liquidators.
     *         For example, if the price of the collateral plummeted before anyone could be liquidated.
     * 
     * Follows CEI (Check, Effects, Interact)
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant{
        // need to check health factor of the user
        uint256 startingHealthFactor = _healthFactor(user);
        if(startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // We want to burn their DSC "debt" and take their collateral
        // Bad User: $140 ETH, $100 DSC
        // debtToCover: $100 DSC
        // $100 of DSC = ??? ETH?
        // 0.05 ETH
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 DSC
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury

        // 0.05 ETH * .1 = 0.005 ETH (Getting a 10% bonus).
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        // We need to burn the DSC
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    ////////////////////////////////////////////////////       
    //      Internal & Private View Functions         //
    ////////////////////////////////////////////////////

    /**
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking for health factor.
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This condition is hypothetically unreachable.
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @dev Aave documentatio for 'Health Factor': https://aave.com/help/borrowing/liquidations
     * Retuns how close to liquidation a user is
     * If a user goes below 1, they can get liquidated
     */
    function _healthFactor(address user) private view returns(uint256) {
        // 1. Total DSC minted
        // 2. Total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // $1000 ETH * 50 = 50,000 / 100 = 500
        // $150 ETH / 100 DSC = 1.5
        // 150 * 50 = 7500 / 100 = (75 / 100) < 1

        // $1000 / 100 DSC
        // 1000 * 50 = 50,000 / 100 = (500 / 100) > 1
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // return (collateralValueInUsd / totalDscMinted); 
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if they don't
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////////       
    //      Public & External View Functions          //
    ////////////////////////////////////////////////////
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256) {
        // price of ETH (token)
        // $/ETH ETH??
        // $2000 / ETH. $1000 = 0.5 ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // ($10e18 * 1e18) / $2000e8 * 1e18)
        return(usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to
        // the price, to get the USD value
        for(uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice Covert a {token, amount} pair to 18 decimal USD value using
     *         Chainlink price feed return 8 decimal numbers, so we use
     *         ADDITIONAL_FEED_PRECISION to scale to 18 decimals.
     */
    function getUsdValue(address token, uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // 1ETH = $2500
        // The return value from Chainlink will be 8 decimal numbers, so we use ADDITIONAL_FEED_PRECISION to scale to 18 decimals.
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
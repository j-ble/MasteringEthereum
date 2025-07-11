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

    //////////////////////////////////
    //      State Variables         //
    //////////////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18; 
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1; 

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

    function depositCollateralAndMintDsc() external {}

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
        external 
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

    function redeemCollateralForDsc() external {}

    // Example of value of collateral dropping to much:
    // $2000 ETH -> $400 ETH
    // $500 DSC -> Liquidated

    // Example of setting a %150 threshold:
    // $2000 ETH -> MUST HAVE $750 ETH 
    // $500 DSC

    function redeemCollateral() external {}

    // check if collateral value > DSC amount
    /**
    * @notice follows CEI (Check, Effects, Interact):
    * @param amountDscToMint The amount of decentralized stable coin to mint.
    * @notice they must have more collateral value than the minimum threshold.
    */
    function mintDsc(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant{
        // Keep track of how much DSC they minted
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted to much, revert
        _revertIfHealthFactorIsBroken(msg.sender);
    }
        
    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    ////////////////////////////////////////////////////       
    //      Internal & Private View Functions         //
    ////////////////////////////////////////////////////
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
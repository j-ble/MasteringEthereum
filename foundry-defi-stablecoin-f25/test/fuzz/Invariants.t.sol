// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
import {DeployDSC} from "../../src/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../src/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

// Have our invariant aka properties that should always hold true

// What are our invariants?
// 1. The total supply of DSC should be less than total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant

contract Invariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address wxrp;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (,,, weth, wbtc, wxrp,) = config.activeNetworkConfig();
        handler = new Handler(engine, dsc);
        targetContract(address(handler));
        // targetContract(address(engine));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        //  Get the vlaue of all the collaterla in the protocol
        // Compare it to  all the debt (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));
        uint256 totalWxrpDeposited = IERC20(wxrp).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
        uint256 wxrpValue = engine.getUsdValue(wxrp, totalWxrpDeposited);

        console.log("weth Value: ", wethValue);
        console.log("wbtc Value: ", wbtcValue);
        console.log("wxrp Value: ", wxrpValue);
        console.log("totalSupply: ", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        assert ((wethValue + wbtcValue + wxrpValue) >= totalSupply);
    }

    // Forge inspect DSCEngine methods
    function invariant_gettersShouldNotRevert() public view {
        engine.getCollateralTokens();
        engine.getPrecision();
    }
}
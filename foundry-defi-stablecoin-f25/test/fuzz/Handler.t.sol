// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Handler is going to narrow down the way we call functions

contract Handler is Test {
    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;
    ERC20Mock wxrp;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        engine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wxrp = ERC20Mock(collateralTokens[2]);
    }

    // reddem collateral
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    // Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        uint256 remainder = collateralSeed % 3;
        if (remainder == 0) {
            return weth;
        } else if (remainder == 1) {
            return wbtc;
        } else {
            return wxrp;
        }
    }
}
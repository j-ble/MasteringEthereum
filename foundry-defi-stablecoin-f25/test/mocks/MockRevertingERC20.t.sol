// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MockRevertingERC20 is ERC20Mock {
    bool public shouldRevert = false;

    function setRevert(bool _shouldRevert) public {
        shouldRevert = _shouldRevert;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (shouldRevert) {
            return false;
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (shouldRevert) {
            return false;
        }
        return super.transferFrom(from, to, value);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/chains/evm/contracts/pools/TokenPool.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {IRebaseToken} from "./interfaces/RebaseToken.I.sol";
import {BurnFromMintTokenPool} from "@ccip/chains/evm/contracts/pools/BurnFromMintTokenPool.sol";

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        uint8 _localTokenDecimals,
        address[] memory _allowlist,
        address _rnmProxy,
        address _router
    ) TokenPool(_token, 18, _allowlist, _rnmProxy, _router) {
        // Constructor body (if any additional logic is needed)
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@chainlink-ccip/pools/TokenPool.sol";
import {IERC20} from "@forge/interfaces/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol"; // Adjust path if your interface is elsewhere
import {Pool} from "@chainlink-ccip/libraries/Pool.sol"; // For CCIP structs

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        uint8 _localTokenDecimals,
        address[] memory _allowList, 
        address _rmnProxy, 
        address _router
    ) TokenPool(_token, _localTokenDecimals, _allowList, _rmnProxy, _router) {
        // Constructor body
    }

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) public override returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        // address originalSender = abi.decode(lockOrBurnIn.originalSender, (address));
        // uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(0)
        }); 
    }

    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) public override returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut) {
        // Calculate the local amount
        uint256 localAmount = _calculateLocalAmount(
            releaseOrMintIn.sourceDenominatedAmount,
            _parseRemoteDecimals(releaseOrMintIn.sourcePoolData)
        );
        // Pass localAmount to the validation function
        _validateReleaseOrMint(releaseOrMintIn, localAmount);

        // Use localAmount instead of releaseOrMintIn.amount
        // uint256 userInterestRate = abi.decode(releaseOrMintIn.PoolData, (uint256));
        IRebaseToken(address(i_token)).mint(
            releaseOrMintIn.receiver,
            localAmount
        );
        return Pool.ReleaseOrMintOutV1({
            destinationAmount: localAmount
        });
    }
}
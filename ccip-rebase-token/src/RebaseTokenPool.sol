// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@chainlink-ccip/pools/TokenPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol"; // Adjust path if your interface is elsewhere
import {Pool} from "@chainlink-ccip/libraries/Pool.sol"; // For CCIP structs

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 token,
        uint8 localTokenDecimals,
        address[] memory allowList, 
        address rmnProxy, 
        address router
    ) TokenPool(token, localTokenDecimals, allowList, rmnProxy, router) {
        // Constructor body
    }

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) public virtual override returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        // Burn the tokens on the source chain. Returns userAccumulatedInterest before the token were burned.
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
        // address originalSender = abi.decode(lockOrBurnIn.originalSender, (address));
        // uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        // encode a function call to pass the caller's info to the destination pool and update it
        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        }); 
    }

    /**
     * @notice Mints the tokens on the source chain
     */
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) public virtual override returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut) {
        uint256 amountToMint = releaseOrMintIn.sourceDenominatedAmount;
        _validateReleaseOrMint(releaseOrMintIn, amountToMint);
        address receiver = releaseOrMintIn.receiver;
        (uint256 userInterestRate) = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        
        // Use localAmount instead of releaseOrMintIn.amount
        // uint256 userInterestRate = abi.decode(releaseOrMintIn.PoolData, (uint256));
        IRebaseToken(address(i_token)).mint(
            receiver,
            amountToMint,
            userInterestRate
        );
        return Pool.ReleaseOrMintOutV1({
            destinationAmount: amountToMint
        });
    }
}
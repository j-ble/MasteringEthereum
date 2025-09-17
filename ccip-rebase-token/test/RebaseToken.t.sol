//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 public SEND_VALUE = 1e5;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    // Fuzz test to check the linear growth of the rebase token
    function testDepositLinear(uint256 amount) public {
        // not using assume because we want to test the edge cases
        // vm.assume(amount > 1e5);
        
        // modify the amount to be less than 0 - 2^96 - 1
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. Check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. Warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        console.log("block.timestamp", block.timestamp);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. Warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("block.timestamp", block.timestamp);
        console.log("endBalance", endBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit the funds
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        // 2. Redeem the funds
        vault.redeem(amount);
        uint256 balance = rebaseToken.balanceOf(user);
        console.log("User balance: %d", balance);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(rebaseToken).balance, 0);
        vm.stopPrank();
    }

    function testRedeemAfterTimePasses(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        // 1. Deposit the funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2. Warp the time
        vm.warp(time);
        // get balance after time has passed
        uint256 balance = rebaseToken.balanceOf(user);
        // 2b. Add the reward to the vault
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);
        // 3. Redeem the funds
        vm.prank(user);
        vault.redeem(balance);

        uint256 ethBalance = address(user).balance;
        
        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        // 1. Deposit the funds
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // Owner reduces the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2. Transfer the funds
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, user2Balance + amountToSend);

        // afyer some time has passed, check the balance of the two users has increased
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterWarp = rebaseToken.balanceOf(user2);
        
        // 3. Check the user interest rate has been inherited (5e10 not 4e10)
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
        // since user had minted before, their interest rate should be the previous interest rate
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(user2BalanceAfterWarp, user2BalanceAfterTransfer);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }

    // function testCannotCallMint() public {
    //     // Deposit some funds
    //     vm.prank(user);
    //     uint256 interestRate = RebaseToken.getInterestRate();
    //     vm.expectRevert();
    //     rebaseToken.mint(user, SEND_VALUE, interestRate);
    //     vm.stopPrank();
    // }

    function testCannotCallBurn() public {
        // Deposit some funds
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, SEND_VALUE);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        // Deposit funds
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }
    
    function testDeposit(uint256 amount) public {
        amount = bound(amount, 1e3, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate + 1, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testSetInterestRateSuccess() public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        uint256 newInterestRate = initialInterestRate - 1; // A lower rate

        vm.prank(owner);
        rebaseToken.setInterestRate(newInterestRate);

        assertEq(rebaseToken.getInterestRate(), newInterestRate);
    }

    function testTransferMaxAmount() public {
        uint256 depositAmount = 1 ether;

        // User deposits funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        address user2 = makeAddr("user2");
        uint256 userStartBalance = rebaseToken.balanceOf(user);

        // User transfers their entire balance using max uint
        vm.prank(user);
        rebaseToken.transfer(user2, type(uint256).max);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(rebaseToken.balanceOf(user2), userStartBalance);
    }

    function testTransferFrom() public {
        uint256 depositAmount = 1 ether;
        uint256 approveAmount = 0.5 ether;
        
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2"); // The spender
        address user3 = makeAddr("user3"); // The recipient

        // 1. User1 deposits funds
        vm.deal(user1, depositAmount);
        vm.prank(user1);
        vault.deposit{value: depositAmount}();
        
        uint256 user1StartBalance = rebaseToken.balanceOf(user1);

        // 2. User1 approves User2 to spend tokens on their behalf
        vm.prank(user1);
        rebaseToken.approve(user2, approveAmount);
        assertEq(rebaseToken.allowance(user1, user2), approveAmount);

        // 3. User2 executes the transferFrom
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user3, approveAmount);

        // 4. Assert balances and allowance
        assertEq(rebaseToken.balanceOf(user1), user1StartBalance - approveAmount);
        assertEq(rebaseToken.balanceOf(user3), approveAmount);
        assertEq(rebaseToken.allowance(user1, user2), 0);
    }

    function testRedeemSpecificAmount() public {
        uint256 depositAmount = 2 ether;
        uint256 redeemAmount = 0.5 ether;

        // User deposits funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        uint256 tokenBalanceBefore = rebaseToken.balanceOf(user);
        uint256 ethBalance = address(user).balance;

        // User redeems a specific amount
        vm.prank(user);
        vault.redeem(redeemAmount);

        assertEq(rebaseToken.balanceOf(user), tokenBalanceBefore - redeemAmount);
        assertEq(address(user).balance, ethBalance + redeemAmount);
    }

    // function testRedeemFailsIfReceiverRejectsETH() public {
    //     // Deploy the helper contract
    //     RejectETH rejector = new RejectETH();
        
    //     uint256 depositAmount = 1 ether;

    //     // The rejector contract deposits funds into the vault
    //     vm.deal(address(rejector), depositAmount);
    //     vm.prank(address(rejector));
    //     vault.deposit{value: depositAmount}();

    //     // Now, expect the redeem to fail with our custom vault error
    //     vm.prank(address(rejector));
    //     vm.expectRevert(Vault.VAULT__REDEEM_FAILED.selector);
    //     vault.redeem(depositAmount);
    // }

    function testTransferFromMaxAmount() public {
        uint256 depositAmount = 1 ether;
        
        address user1 = makeAddr("user1"); // The owner of the tokens
        address user2 = makeAddr("user2"); // The spender
        address user3 = makeAddr("user3"); // The recipient

        // 1. User1 deposits funds
        vm.deal(user1, depositAmount);
        vm.prank(user1);
        vault.deposit{value: depositAmount}();
        
        uint256 user1StartBalance = rebaseToken.balanceOf(user1);

        // 2. User1 approves User2 to spend their ENTIRE balance
        vm.prank(user1);
        rebaseToken.approve(user2, type(uint256).max);

        // 3. User2 executes the transferFrom with `max`, triggering the uncovered branch
        vm.prank(user2);
        rebaseToken.transferFrom(user1, user3, type(uint256).max);

        // 4. Assert that User1's entire balance was transferred to User3
        assertEq(rebaseToken.balanceOf(user1), 0);
        assertEq(rebaseToken.balanceOf(user3), user1StartBalance);
    }
}
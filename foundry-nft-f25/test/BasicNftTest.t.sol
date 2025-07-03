// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../lib/forge-std/src/Test.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract BasicNftTest is Test {
    BasicNft private basicNft;
    
    // This will be our test user's address
    // We declare it here and will initialize it in setUp()
    address private user; 

    string public constant TOKEN_URI = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    function setUp() public {
        basicNft = new BasicNft();
        
        // Using the Foundry cheatcode `makeAddr` to create a deterministic address for our "user"
        user = makeAddr("user");
    }

    function testConstructorInitializesCorrectly() public view {
        assertEq(basicNft.name(), "Dogie");
        assertEq(basicNft.symbol(), "DOG");
    }

    function testMintNft() public {
        vm.prank(user); // Prank as our named user
        basicNft.mintNft(TOKEN_URI);

        assertEq(basicNft.tokenURI(0), TOKEN_URI);
        assertEq(basicNft.ownerOf(0), user);
        assertEq(basicNft.balanceOf(user), 1);
    }
    
    function testTokenCounterIncrements() public {
        vm.startPrank(user);
        basicNft.mintNft(TOKEN_URI);
        
        basicNft.mintNft(TOKEN_URI);

        vm.stopPrank();
        
        assertEq(basicNft.ownerOf(1), user);
    }

    function testTokenURIReturnsEmptyForNonExistentToken() public view {
        assertEq(basicNft.tokenURI(123), "");
    }
}
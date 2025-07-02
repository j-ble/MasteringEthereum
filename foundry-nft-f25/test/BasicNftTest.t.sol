// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract BasicNftTest is Test {
    BasicNft private basicNft;
    address public constant USER = address(1);
    string public constant TOKEN_URI = "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

    // This function runs before each test, deploying a fresh contract instance.
    function setUp() public {
        basicNft = new BasicNft();
    }

    // Test 1: Verifies the constructor sets the name and symbol correctly.
    function testConstructorInitializesCorrectly() public view {
        assertEq(basicNft.name(), "Dogie");
        assertEq(basicNft.symbol(), "DOG");
    }

    // Test 2: Verifies the entire minting process.
    function testMintNft() public {
        // We'll mint the NFT from the USER address, not the test contract's address.
        vm.prank(USER);
        basicNft.mintNft(TOKEN_URI);

        // Assert that the token URI was stored correctly for tokenId 0.
        assertEq(basicNft.tokenURI(0), TOKEN_URI);
        // Assert that the owner of tokenId 0 is the USER.
        assertEq(basicNft.ownerOf(0), USER);
        // Assert that the USER's balance is now 1.
        assertEq(basicNft.balanceOf(USER), 1);
    }
    
    // Test 3: Test that the token counter increments
    function testTokenCounterIncrements() public {
        // Tell the VM that the USER is calling the next function
        vm.prank(USER);
        basicNft.mintNft(TOKEN_URI);

        // Tell the VM that the USER is calling the next function again
        vm.prank(USER);
        basicNft.mintNft(TOKEN_URI);
        
        // The first token (ID 0) and second token (ID 1) should belong to USER.
        // We check the owner of the second token to prove it was minted.
        assertEq(basicNft.ownerOf(1), USER);
    }


    // Test 4: Verifies that calling tokenURI for a non-existent token
    // returns an empty string, as per our specific implementation.
    function testTokenURIReturnsEmptyForNonExistentToken() public view {
        // Token ID 123 does not exist.
        assertEq(basicNft.tokenURI(123), "");
    }
}
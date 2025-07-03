// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MoodNft is ERC721 {
    uint256 private s_toekenCounter;
    string private s_sadSvg;
    string private s_happySvg;

    constructor(string memory sadSvg, string memory happySvg) ERC721("Mood NFT", "MN") {
        s_toekenCounter = 0;
        s_sadSvg = sadSvg;
        s_happySvg = happySvg;
    }

    function mintNft() public {
        _safeMint(msg.sender, s_toekenCounter);
        s_toekenCounter++;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {}
}
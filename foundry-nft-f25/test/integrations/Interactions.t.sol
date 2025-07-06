// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {DeployBasicNft} from "../../script/DeployBasicNft.s.sol";
import {BasicNft} from "../../src/BasicNft.sol";
import {Interactions} from "../../script/Interactions.s.sol";
import {DevOpsTools} from "../../lib/foundry-devops/src/DevOpsTools.sol";

contract InteractionsTest is Test {}
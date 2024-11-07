// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-reflax/Test.sol";
import {BoosterV1_lib} from "@reflax/booster/BoosterV1_lib.sol";

contract test_Stateless is Test {
    function setUp() public {}

    function testSetup() public view {}

    // emit claimValues(unclaimed: 404548916133686000000000 [4.045e23], flaxToTransfer: 10000 [1e4], sFlaxBalance: 0)
    function testPercentageBoostReturnsPositive() public pure {
        uint256 boost = BoosterV1_lib.percentageBoost(10_000, 0);
        vm.assertEq(boost, 0);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-reflax/Test.sol";
import {BoosterV1_lib} from "@reflax/booster/BoosterV1_lib.sol";

contract test_Stateless is Test {
    function setUp() public {}

    function testSetup() public view {}

    // emit claimValues(unclaimed: 404548916133686000000000 [4.045e23], flaxToTransfer: 10000 [1e4], sFlaxBalance: 0)
    function testPercentageBoostReturnsPositive() public pure {
        uint256 boost = BoosterV1_lib.percentageBoost(10_000, 0, 100_000);
        vm.assertEq(boost, 10_000);
    }

    function testStandardAmoutBoost() public pure {
        uint256 boost = BoosterV1_lib.percentageBoost(10_000, 1000 ether, 100_000);
        vm.assertEq(boost, 10100); //1%
    }

    function testMaxBoost() public pure {
        uint256 boost = BoosterV1_lib.percentageBoost(10_000, 200_000 ether, 100_000);
        vm.assertEq(boost, 30_000); //100%

        boost = BoosterV1_lib.percentageBoost(10_000, 200_001 ether, 100_000);
        vm.assertEq(boost, 30_000); //100%

        boost = BoosterV1_lib.percentageBoost(10_000, 300_001 ether, 100_000);
        vm.assertEq(boost, 30_000); //100%

        boost = BoosterV1_lib.percentageBoost(10_000, 200_000 ether - 1, 100_000);
        vm.assertEq(boost, 29_999); //100%
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-reflax/Test.sol";
import {USDC_v1_lib} from "@reflax/vaults/USDC_v1_lib.sol";
import {BaseVaultLib} from "@reflax/vaults/BaseVaultLib.sol";

contract test_Stateless is Test {
    function setUp() public {}

    function testSetup() public view {}

    function test_calculate_derived_yield_increment_minute() public pure {
        //0 time returns 0
        uint256 flaxPerShare = USDC_v1_lib.calculate_derived_yield_increment(10_000, 10, 10, 1e6, 1e10);
        vm.assertEq(flaxPerShare, 0);

        uint256 ethPerUSDC = 4000; //note this is multiplied by 10^7
        uint256 ethPerFlax = 5;

        //tera usdc per share
        uint256 TVIPS = 3179;

        uint256 lastUpdate = 10;
        uint256 present = 70; //one minute

        //USDC per second: 0.000000003
        flaxPerShare = USDC_v1_lib.calculate_derived_yield_increment(TVIPS, lastUpdate, present, ethPerUSDC, ethPerFlax);

        vm.assertEq(flaxPerShare, 152592000000000);
    }

    function test_calculate_derived_yield_increment_year() public pure {
        uint256 ethPerUSDC = 4000; //note this is multiplied by 10^7
        uint256 ethPerFlax = 5;

        //tera usdc per share
        uint256 TVIPS = 3179;

        uint256 lastUpdate = 2000;
        uint256 present = 31538000; //one minute

        uint256 flaxPerShare =
            USDC_v1_lib.calculate_derived_yield_increment(TVIPS, lastUpdate, present, ethPerUSDC, ethPerFlax);

        vm.assertEq(flaxPerShare, 80202355200000000000);
    }

    function test_calculate_derived_yield_increment_year_bigger_factor() public pure {
        uint256 ethPerUSDC = 4000000; //note this is multiplied by 10^10
        uint256 ethPerFlax = 5000;

        //tera usdc per share
        uint256 TVIPS = 3179;

        uint256 lastUpdate = 2000;
        uint256 present = 31538000; //one minute

        uint256 flaxPerShare =
            USDC_v1_lib.calculate_derived_yield_increment(TVIPS, lastUpdate, present, ethPerUSDC, ethPerFlax);

        //assumes there is liquidity in both pairs
        vm.assertEq(flaxPerShare, 80202355200000000000);
    }

    // 402097791907346190 [4.02e17], ethPerFlax: 999999

    function test_calculate_derived_yield_increment_1_minute_realistic_data() public pure {
        uint256 ethPerUSDC = 402097791907346190; //note this is multiplied by 10^10
        uint256 ethPerFlax = 999999;

        //tera usdc per share
        uint256 TVIPS = 3179;

        uint256 lastUpdate = 2000;
        uint256 present = 2060; //one minute

        uint256 flaxPerShare =
            USDC_v1_lib.calculate_derived_yield_increment(TVIPS, lastUpdate, present, ethPerUSDC, ethPerFlax);

        //assumes there is liquidity in both pairs
        vm.assertEq(flaxPerShare, 76696209524616736897336);
    }

    function test_multiple_stakers_receive_correctReward() public pure {
        uint256 flaxRewardPerShare = 0;

        uint256 user1Share = 100;
        uint256 user2Share = 200;

        uint256 user1PriorReward = 0;
        uint256 user2PriorReward = 0;
        //user1 claims after reward grows by 100;

        uint256 newReward = 100;

        (uint256 newAggregate, uint256 unclaimedFlax) =
            BaseVaultLib.updateStakeAccounting(flaxRewardPerShare, user1PriorReward, user1Share, newReward);

        user1PriorReward = newAggregate;
        flaxRewardPerShare = newAggregate;

        vm.assertEq(unclaimedFlax, 10_000);

        //user 2 claims after another reward of 50.

        newReward = 50;

        (newAggregate, unclaimedFlax) =
            BaseVaultLib.updateStakeAccounting(flaxRewardPerShare, user2PriorReward, user2Share, newReward);

        uint256 expectedUnclaimed = 30_000;

        vm.assertEq(unclaimedFlax, expectedUnclaimed);

        user2PriorReward = newAggregate;
        flaxRewardPerShare = newAggregate;

        //user 1 claims after another 50. Should only get the latest 50 and not all.

        (newAggregate, unclaimedFlax) =
            BaseVaultLib.updateStakeAccounting(flaxRewardPerShare, user1PriorReward, user1Share, newReward);

        vm.assertEq(unclaimedFlax, 10000);
    }
    //  ├─ emit FlaxReward(ethPerUSDC: 349091007028080 [3.49e14], ethPerFlax: 999999999999999 [9.999e14], lastUpdate: 1730950749 [1.73e9], timestamp: 1730986749 [1.73e9], duration: 36000 [3.6e4])

    function test_calculate_derived_yield_increment_specific() public pure {
        //0 time returns 0
        uint256 flaxPerShare = USDC_v1_lib.calculate_derived_yield_increment(10_000, 10, 10, 1e6, 1e10);
        vm.assertEq(flaxPerShare, 0);

        uint256 ethPerUSDC = 349091007028080; //note this is multiplied by 10^7
        uint256 ethPerFlax = 999999999999999;

        //tera usdc per share
        uint256 TVIPS = 3179;

        uint256 lastUpdate = 10;
        uint256 present = 36010; //one minute

        //USDC per second: 0.000000003
        flaxPerShare = USDC_v1_lib.calculate_derived_yield_increment(TVIPS, lastUpdate, present, ethPerUSDC, ethPerFlax);

        vm.assertEq(flaxPerShare, 39951371208321);
    }
}

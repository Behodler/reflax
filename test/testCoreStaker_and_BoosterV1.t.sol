// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "../src/governance/CoreStaker.sol";
import {TokenLockupPlans} from "./mocks/TokenLockupPlans_managed_time.sol";

import {HedgeyAdapter} from "../src/governance/HedgeyAdapter.sol";

contract Flax is ERC20 {
    constructor() ERC20("FLAX", "FLX") {}

    function mint(uint amount, address recipient) public {
        _mint(recipient, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
}

contract testCoreStaker_and_BoosterV1 is Test {
    CoreStaker staker;
    Flax flax;
    address user1 = address(0x1);
    address user2 = address(0x2);
    TokenLockupPlans tokenLockupPlan;

    function hedgeyAdapter() public view returns (HedgeyAdapter) {
        (, HedgeyAdapter hedgey) = staker.config();
        return hedgey;
    }

    function setUp() public {
        flax = new Flax();
        tokenLockupPlan = new TokenLockupPlans("Hedgey", "hedgey", address(vm));

        staker = new CoreStaker(
            address(flax),
            address(tokenLockupPlan),
            address(vm)
        );
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);

        flax.mint(3000 ether, user1);
        vm.prank(user1);
        flax.approve(address(staker), type(uint).max);

        flax.mint(3000 ether, user2);
        vm.prank(user2);
        flax.approve(address(staker), type(uint).max);

        LinenStats memory stats_before;
        (
            stats_before.lastUpdatedTimeStamp,
            stats_before.linen,
            stats_before.weight,
            stats_before.remainingBalance
        ) = staker.linenStats(user1);
        vm.assertEq(
            stats_before.lastUpdatedTimeStamp +
                stats_before.linen +
                stats_before.weight +
                stats_before.remainingBalance,
            0
        );
    }

    function test_empty() public {}

    function test_staking_fails() public {
        vm.expectRevert("CoreStaker: stake for at least 1 month");
        staker.stake(10000, 0);

        vm.expectRevert("CoreStaker: maximum stake duration 4 years");
        staker.stake(10000, 209);

        vm.expectRevert(
            "CoreStaker: Staked units must be in thousands of Flax"
        );
        staker.stake(999, 10);

        vm.expectRevert(
            "CoreStaker: Staked units must be in thousands of Flax"
        );
        staker.stake(1100, 10);
    }

    function test_staking_locks_unlocks_correcty() public {
        vm.warp(block.timestamp + 61 * 60);
        vm.roll(block.number + 1);
        vm.prank(user1);
        staker.stake(3000 ether, 12);

        uint lockedBalance = hedgeyAdapter().remainingBalance(user1);
        vm.assertEq(lockedBalance, 3000 ether);

        LinenStats memory stats_after;
        (
            stats_after.lastUpdatedTimeStamp,
            stats_after.linen,
            stats_after.weight,
            stats_after.remainingBalance
        ) = staker.linenStats(user1);

        vm.assertTrue(
            stats_after.lastUpdatedTimeStamp >= 3660 &&
                stats_after.lastUpdatedTimeStamp < 3670
        );
        vm.assertEq(stats_after.weight, 36000);
        vm.assertEq(stats_after.linen, 0);

        uint timestamp_before = block.timestamp;
        uint year = 31104000;

        vm.warp(timestamp_before + year - 1000);
        vm.roll(block.number + 1);
        tokenLockupPlan.redeemAllPlans();

        uint lockedBalance_after_almonst_year = hedgeyAdapter()
            .remainingBalance(user1);
        vm.assertEq(lockedBalance_after_almonst_year, 3000 ether);

        vm.warp(timestamp_before + year + 1);
        vm.roll(block.number + 1);

        vm.prank(user1);
        tokenLockupPlan.redeemAllPlans();
        uint lockedBalance_after_year = hedgeyAdapter().remainingBalance(user1);
        vm.assertEq(lockedBalance_after_year, 0);
    }

    function test_multiple_locks_decays_weight_as_redeems_happen() public {
        uint iterations = envWithDefault("iterations", 12);
        uint amount = envWithDefault("amount", 2000) * (1 ether);
        flax.mint(iterations * amount, user1);

        for (uint months = 1; months <= iterations; months++) {
            uint lockedBalanceBefore = hedgeyAdapter().remainingBalance(user1);
            vm.prank(user1);
            staker.stake(amount, months);
            uint lockedBalanceAfter = hedgeyAdapter().remainingBalance(user1);
            vm.assertEq(lockedBalanceAfter - lockedBalanceBefore, amount);
        }

        LinenStats memory stats;
        (
            stats.lastUpdatedTimeStamp,
            stats.linen,
            stats.weight,
            stats.remainingBalance
        ) = staker.linenStats(user1);
        vm.assertGt(stats.weight, 0);

        uint MONTH = (30 days) + 10;

        uint blockNumberBefore = block.number;
        uint initialBalance = flax.balanceOf(user1);
        vm.prank(user1);
        flax.burn(initialBalance);

        uint assertions = envWithDefault("assertions", iterations);

        uint balance_before;
        uint balance_after;
        uint previousTimestamp = 0;
        for (uint i = 1; i <= assertions; i++) {
            uint currentTimestamp = vm.getBlockTimestamp();
            vm.assertGt(currentTimestamp, previousTimestamp);
            vm.warp(vm.getBlockTimestamp() + MONTH);
            vm.roll(blockNumberBefore + i);
            previousTimestamp = currentTimestamp;

            balance_before = flax.balanceOf(user1);
            //sanity check because of vm warp
            vm.assertEq(balance_after, balance_before);
            vm.prank(user1);
            tokenLockupPlan.redeemAllPlans();
            balance_after = flax.balanceOf(user1);
            uint growth = balance_after - balance_before;
            vm.assertEq(growth, amount);
            uint weightBefore = stats.weight;

            //decay the weight
            staker.decayExistingWeight(user1);
            (, , stats.weight, ) = staker.linenStats(user1);

            vm.assertGt(weightBefore, stats.weight);

            //this if block is just to check that the weight doesn't prematurely reach zero.
            if (i < iterations) {
                vm.assertGt(stats.weight, 0);
            } else {
                vm.assertEq(stats.weight, 0);
            }
        }
    }

    //f(a+b)=f(a)+f(b)
    function test_weights_are_additive() public {
        flax.mint(100_000 ether, user1);
        flax.mint(100_000 ether, user2);
        uint stake_units = 1e21;
        vm.prank(user1);
        staker.stake(65 * stake_units, 2);
        vm.prank(user1);
        staker.stake(35 * stake_units, 2);

        vm.prank(user2);
        staker.stake(100 * stake_units, 2);

        LinenStats memory stats_user1;
        (, , stats_user1.weight, stats_user1.remainingBalance) = staker
            .linenStats(user1);

        LinenStats memory stats_user2;
        (, , stats_user2.weight, stats_user2.remainingBalance) = staker
            .linenStats(user2);

        vm.assertEq(stats_user1.remainingBalance, stats_user2.remainingBalance);

        vm.assertGt(stats_user1.remainingBalance, 0);
        // vm.assertEq(stats_user1.weight, 0);
        vm.assertEq(stats_user1.weight, stats_user2.weight);
    }

    function test_doubling_time_is_like_doubling_quantity() public {
        flax.mint(100_000 ether, user1);
        flax.mint(100_000 ether, user2);
        uint stake_units = 1e21;

        LinenStats memory stats_user1;
        (, , stats_user1.weight, stats_user1.remainingBalance) = staker
            .linenStats(user1);

        LinenStats memory stats_user2;
        (, , stats_user2.weight, stats_user2.remainingBalance) = staker
            .linenStats(user2);

        vm.assertEq(stats_user1.weight, 0);
        vm.assertEq(stats_user2.weight, 0);

        vm.prank(user1);
        staker.stake(50 * stake_units, 4);

        vm.prank(user2);
        staker.stake(100 * stake_units, 2);

        (, , stats_user1.weight, stats_user1.remainingBalance) = staker
            .linenStats(user1);

        (, , stats_user2.weight, stats_user2.remainingBalance) = staker
            .linenStats(user2);
        // vm.assertEq(stats_user1.weight, 0);
        vm.assertEq(stats_user1.weight, stats_user2.weight);
    }

    function test_linen_scaling() public {
        flax.mint(100_000 ether, user1);
        flax.mint(100_000 ether, user2);
        LinenStats memory stats_user1;
        (, stats_user1.linen, , ) = staker.linenStats(user1);

        LinenStats memory stats_user2;
        (, stats_user2.linen, , ) = staker.linenStats(user2);

        vm.assertEq(stats_user1.linen, 0);
        vm.assertEq(stats_user2.linen, 0);

        uint stake_units = 1e21;
        vm.prank(user1);
        staker.stake(50 * stake_units, 4);

        vm.prank(user2);
        staker.stake(100 * stake_units, 2);

        (stats_user1.lastUpdatedTimeStamp, stats_user1.linen, , ) = staker
            .linenStats(user1);

        (stats_user2.lastUpdatedTimeStamp, stats_user2.linen, , ) = staker
            .linenStats(user2);

        vm.assertEq(
            stats_user1.lastUpdatedTimeStamp,
            stats_user2.lastUpdatedTimeStamp
        );

        //warp 100 minutes
        vm.warp(vm.getBlockTimestamp() + 60*60);

        staker.updateLinenBalance(user1);
        staker.updateLinenBalance(user2);

        (stats_user1.lastUpdatedTimeStamp, stats_user1.linen, stats_user1.weight, ) = staker
            .linenStats(user1);

        (stats_user2.lastUpdatedTimeStamp, stats_user2.linen,stats_user2.weight , ) = staker
            .linenStats(user2);


        vm.assertEq(
            stats_user1.lastUpdatedTimeStamp,
            stats_user2.lastUpdatedTimeStamp
        );

        vm.assertEq(stats_user1.weight,stats_user2.weight);
        vm.assertGt(stats_user1.linen, 0);
        vm.assertGt(stats_user2.linen, 0);

        vm.assertEq(stats_user1.linen, stats_user2.linen);
        vm.assertEq(stats_user1.linen/1000, 0);        
    }

    function envWithDefault(
        string memory env_var,
        uint defaultVal
    ) public view returns (uint envValue) {
        try this.getEnvValue(env_var) returns (uint value) {
            envValue = value;
        } catch {
            // Fallback value if environment variable is missing
            envValue = defaultVal; // Default value
        }
    }

    // This external function is required for using try-catch
    function getEnvValue(string memory env_var) external view returns (uint) {
        return vm.envUint(env_var);
    }
}

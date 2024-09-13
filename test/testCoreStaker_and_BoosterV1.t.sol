// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "../src/governance/CoreStaker.sol";
import {TokenLockupPlans} from "@hedgey/lockup/TokenLockupPlans.sol";
import {HedgeyAdapter} from "../src/governance/HedgeyAdapter.sol";

contract Flax is ERC20 {
    constructor() ERC20("FLAX", "FLX") {}

    function mint(uint amount) public {
        _mint(msg.sender, amount);
    }
}

contract testCoreStaker_and_BoosterV1 is Test {
    CoreStaker staker;
    Flax flax;

    address user = address(0x1);

    function hedgeyAdapter () public returns (HedgeyAdapter) {
        (,HedgeyAdapter hedgey) = staker.config();
        return hedgey;
    }

    function setUp() public {
        flax = new Flax();
        TokenLockupPlans tokenLockupPlan = new TokenLockupPlans(
            "Hedgey",
            "hedgey"
        );


        staker = new CoreStaker(address(flax), address(tokenLockupPlan));
    }

    function test_empty() public {}

    function test_staking_fails() public {
        vm.expectRevert();
        staker.stake(10, 0);

        vm.expectRevert();
        staker.stake(209, 0);
    }

    function test_staking_locks_and_updates_weight() public {
        vm.deal(user, 10000 ether);
        flax.mint(1000 ether);
        flax.transfer(user, 1000 ether);
        vm.prank(user);
        flax.approve(address(staker), 1e12 ether);
        vm.prank(user); 
        staker.stake_temp(1000 ether, 12);

        uint lockedBalance = hedgeyAdapter().remainingBalance(user);
        vm.assertEq(lockedBalance,1000 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {Test} from "@forge-reflax/Test.sol";
import {BoosterV1} from "@reflax/booster/BoosterV1.sol";

contract Flax is ERC20 {
    constructor() ERC20("FLAX", "FLX") {}

    function mint(uint amount, address recipient) public {
        _mint(recipient, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
}

contract testBoosterV1 is Test {
    Flax flax;
    Flax sFlax;
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        flax = new Flax();
        sFlax = new Flax();

        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);

        flax.mint(3000 ether, user1);
        vm.prank(user1);

        flax.mint(3000 ether, user2);
        vm.prank(user2);
    }

    function test_empty() public {}

    function test_booster_gives_correct_boost_at_all_levels() public {
        sFlax.mint(9 ether, user1);
        BoosterV1 booster = new BoosterV1(address(sFlax));
        vm.assertEq(booster.BasisPoints(), 10_000);

        (uint boost, uint sFlaxBalanceToBurn) = booster.percentageBoost(
            user1,
            0
        );

        vm.assertEq(boost, 0);
        vm.assertEq(sFlaxBalanceToBurn, 0);

        sFlax.mint(1 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 1);
        vm.assertEq(sFlaxBalanceToBurn, 10 ether);

        sFlax.mint(10 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 2);
        vm.assertEq(sFlaxBalanceToBurn, 20 ether);

        sFlax.mint(180 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 20);
        vm.assertEq(sFlaxBalanceToBurn, 200 ether);

        sFlax.mint(400 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 60);
        vm.assertEq(sFlaxBalanceToBurn, 600 ether);

        sFlax.mint(19400 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 2000);
        vm.assertEq(sFlaxBalanceToBurn, 20000 ether);

        sFlax.mint(180_000 ether, user1);

        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 20_000);
        vm.assertEq(sFlaxBalanceToBurn, 200_000 ether);

        sFlax.mint(500_000 ether, user1);

        //assert max out
        (boost, sFlaxBalanceToBurn) = booster.percentageBoost(user1, 0);
        vm.assertEq(boost, 20_000);
        vm.assertEq(sFlaxBalanceToBurn, 200_000 ether);
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

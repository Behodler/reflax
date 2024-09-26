// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";

import {Vm} from "forge-std/Test.sol";

contract DebugTimeKeeper {
    Vm vm;

    constructor(Vm _vm) {
        vm = _vm;
    }

    function timestamp() public view returns (uint) {
        return vm.getBlockTimestamp();
    }
}

interface ITokenLockupPlans {
    function lockedBalances(
        address holder,
        address token
    ) external view returns (uint256 lockedBalance);

    function createPlan(
        address recipient,
        address token,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 rate,
        uint256 period
    ) external returns (uint256 newPlanId);

    function redeemAllPlans() external;
}

///This particular incarnation does not stream. Instead it locks for the duration.
contract HedgeyAdapter {
    IERC20 _flax;
    ITokenLockupPlans public tokenLockupPlan;
    DebugTimeKeeper debugTimeKeeper;
    bool useDebugTime;

    constructor(address flax, address hedgey, address vm) {
        _flax = IERC20(flax);
        tokenLockupPlan = ITokenLockupPlans(hedgey);

        if (vm != address(0)) {
            useDebugTime = true;
            debugTimeKeeper = new DebugTimeKeeper(Vm(vm));
        }
    }

    function oneTimeFlaxApprove() public {
        _flax.approve(address(tokenLockupPlan), type(uint).max);
    }

    //function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    function remainingBalance(address holder) public view returns (uint) {
        require(
            address(tokenLockupPlan) != address(0),
            "tokenLockupPlans is null"
        );
        return tokenLockupPlan.lockedBalances(holder, address(_flax));
    }

    function lock(
        address recipient,
        uint amount,
        uint durationInSeconds
    ) external returns (uint nft) {
        uint period = durationInSeconds;

        return
            tokenLockupPlan.createPlan(
                recipient,
                address(_flax),
                amount,
                useDebugTime ? debugTimeKeeper.timestamp() : block.timestamp,
                0,
                amount,
                period
            );
    }
}

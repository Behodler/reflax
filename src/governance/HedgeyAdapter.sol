// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {TokenLockupPlans} from "@hedgey/lockup/TokenLockupPlans.sol";


///This particular incarnation does not stream. Instead it locks for the duration.
contract HedgeyAdapter {
    IERC20 _flax;
    TokenLockupPlans public tokenLockupPlan;

    constructor(address flax, address hedgey) {
        _flax = IERC20(flax);
        tokenLockupPlan = TokenLockupPlans(hedgey);
    }

    function oneTimeFlaxApprove() public {
        _flax.approve(address(tokenLockupPlan), type(uint).max);
    }

    //function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    function remainingBalance (address holder) public view returns (uint){
        return tokenLockupPlan.lockedBalances(holder,address(_flax));
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
                block.timestamp + 60,
                0,
                amount,
                period
            );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {AConvexBooster} from "../../src/yieldSources/convex/USDe_USDx_ys.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {MockCVXPool} from "./MockCVXPool.sol";

contract MockConvexBooster is AConvexBooster {
    function addPool(address crvPool, address cvxPool) public {
        poolInfo.push(
            PoolInfo({
                lptoken: crvPool,
                token: cvxPool,
                gauge: address(0),
                crvRewards: address(0),
                stash: address(0),
                shutdown: false
            })
        );
    }

    event poolToken(address token, uint balance);

    function depositAll(
        uint256 _pid,
        uint upTo
    ) public override returns (bool) {
        PoolInfo memory pool = poolInfo[_pid];
        require(upTo > 99306, "Up To DepositAll");
        IERC20 crvPool = IERC20(pool.lptoken);
        uint balance = crvPool.balanceOf(msg.sender);
        emit poolToken(pool.lptoken, balance);
        require(upTo > 99310, "Up To DepositAll");
        
        crvPool.transferFrom(msg.sender, pool.token, balance);
        require(upTo > 99320, "Up To DepositAll");

        MockCVXPool(pool.token).mint(msg.sender, balance);
        require(upTo > 99330, "Up To DepositAll");
        return true;
    }
}

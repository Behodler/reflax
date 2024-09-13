// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {AConvexBooster} from "../../src/yieldSources/convex/USDe_USDx.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {MockCVXPool} from './MockCVXPool.sol';

contract MockConvexBooster is AConvexBooster{
    
     function addPool(address crvPool, address cvxPool) public {
        poolInfo.push(PoolInfo({
            lptoken:crvPool,
            token:cvxPool,
            gauge:address(0),
            crvRewards:address(0),
            stash:address(0),
            shutdown:false
        }));
    }

    function depositAll(uint256 _pid) public override returns (bool){
        PoolInfo memory pool = poolInfo[_pid];
        IERC20 crvPool = IERC20(pool.lptoken);
        uint balance = crvPool.balanceOf(msg.sender);
        crvPool.transferFrom(msg.sender,pool.token,balance);
        MockCVXPool(pool.token).mint(msg.sender,balance);
    }
}
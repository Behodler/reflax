// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {CVX_pool} from "../../src/yieldSources/convex/USDe_USDx.sol";
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {MockCRVPool} from "./MockCRVPool.sol";
import {MockCRVToken} from "./MockCRVToken.sol";

contract MockCVXPool is CVX_pool, IERC20 {
    MockCRVPool stakedCRV;
    MockCRVToken crvToken;
    uint public totalSupply;
    mapping(address => uint) balances;
    mapping(address => uint) lastClaimTimestamp;

    function withdraw(
        uint256 _amount,
        bool _claim
    ) public override returns (bool) {
        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakedCRV.transferFrom(address(this), msg.sender, _amount);
        if (_claim) {
            claim(msg.sender);
        }
        return true;
    }

    function withdrawAll(bool _claim) public override {
        uint entireBalance = balances[msg.sender];
        withdraw(entireBalance, _claim);
    }


    function getReward(address _account) external override {}

    function claim(address recipient) public {
        uint lastClaim = lastClaimTimestamp[msg.sender];
        lastClaimTimestamp[msg.sender] = block.timestamp;
        uint duration = block.timestamp - lastClaim;
        crvToken.mint(recipient, duration * (1 ether));
    }
}

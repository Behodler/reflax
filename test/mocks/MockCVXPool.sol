// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {CVX_pool} from "../../src/yieldSources/convex/USDe_USDx_ys.sol";
import {ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {MockCRVPool} from "./MockCRVPool.sol";
import {MockCRVToken} from "./MockCRVToken.sol";

contract MockCVXPool is CVX_pool, ERC20 {
    MockCRVPool stakedCRV;
    MockCRVToken crvGovernanceToken;
    mapping(address => uint) lastClaimTimestamp;

    constructor(
        address _stakedCrv,
        address _crvGovernanceToken
    ) ERC20("Convex", "CVx") {
        stakedCRV = MockCRVPool(_stakedCrv);
        crvGovernanceToken = MockCRVToken(_crvGovernanceToken);
    }

    function mint(address recipient, uint amount) public {
        _mint(recipient, amount);
    }

    function withdraw(
        uint256 _amount,
        bool _claim
    ) public override returns (bool) {
        _burn(msg.sender, _amount);
        stakedCRV.transferFrom(address(this), msg.sender, _amount);
        if (_claim) {
            getReward(msg.sender);
        }
        return true;
    }

    function withdrawAll(bool _claim) public override {
        uint entireBalance = balanceOf(msg.sender);
        withdraw(entireBalance, _claim);
    }

    function getReward(address _account) public override {
        //95100
        uint lastClaim = lastClaimTimestamp[msg.sender];
        lastClaimTimestamp[msg.sender] = block.timestamp;
        uint duration = block.timestamp - lastClaim;
        crvGovernanceToken.mint(_account, duration * (1 ether));
    }
}

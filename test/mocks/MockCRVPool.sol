// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {CRV_pool} from "../../src/yieldSources/convex/USDe_USDx.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";

contract MockCRVPool is CRV_pool {
    IERC20[] tokens; //0 = USDe,1 = USDc
    uint _totalSupply;
    uint constant ONE = 1 ether;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) approvals;

    function approve(address spender, uint amount) public {
        approvals[msg.sender][spender] += amount;
    }

    function transferFrom(
        address holder,
        address recipient,
        uint amount
    ) public {
        if (holder != msg.sender) {
            approvals[holder][msg.sender] -= amount;
        }
        balances[holder] -= amount;
        balances[recipient] -= amount;
    }

    constructor(address usdcAddress, address usdeAddress) {
        tokens.push(IERC20(usdeAddress));
        tokens.push(IERC20(usdcAddress));
    }

    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }

    //For USDC in, get_dy(1,0,1e6) returns approx 1e18
    function get_dy(
        uint128 i,
        uint128 j,
        uint dx
    ) public view override returns (uint) {}

    //remember to approve
    //use above to get_dy and then pass it into exchnage below
    function exchange(
        uint128 i,
        uint128 j,
        uint _dx,
        uint _min_dy,
        address receiver
    ) public override {}

    function addLiquidity(
        uint256[] memory _amounts,
        uint256 _minMintAmount,
        address _receiver
    ) public override returns (uint256) {
        uint mintAmount = (_amounts[0] + _amounts[1]) / 2;
        require(mintAmount < _minMintAmount, "min minAmount");
        tokens[0].transferFrom(msg.sender, address(this), _amounts[0]);
        tokens[1].transferFrom(msg.sender, address(this), _amounts[1]);

        _totalSupply += mintAmount;
        balances[_receiver] += mintAmount;
        return mintAmount;
    }

    function get_balances() public view override returns (uint[] memory) {
        uint[] memory internalBal = new uint[](2);
        internalBal[0] = tokens[0].balanceOf(address(this));
        internalBal[1] = tokens[1].balanceOf(address(this));
        return internalBal;
    }

    function remove_liquidity_one_coin(
        uint _burn_amount,
        int128 i,
        uint _min_received,
        address receiver
    ) public override returns (uint256) {
        uint index = uint256(uint128(i));
        uint tokensToWithdraw = calc_withdraw_one_coin(_burn_amount, i);
        require(tokensToWithdraw >= _min_received, "Not enough");
        tokens[index].transfer(receiver, tokensToWithdraw);
        _totalSupply -= _burn_amount;
        balances[msg.sender] -= _burn_amount;
        return tokensToWithdraw;
    }

    function calc_withdraw_one_coin(
        uint256 _burn_amount,
        int128 i
    ) public view override returns (uint256) {
        uint[] memory _bals = get_balances();
        uint index = uint256(uint128(i));
        uint tokenPrice = (_bals[index] * ONE) / (_totalSupply * 2);
        uint tokensToWithdraw = tokenPrice * _burn_amount;
        return tokensToWithdraw;
    }
}

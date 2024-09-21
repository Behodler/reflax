// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {CRV_pool} from "../../src/yieldSources/convex/USDe_USDx_ys.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";

contract MockCRVPool is CRV_pool {
    IERC20[] tokens; //0 = USDe,1 = USDc
    uint _totalSupply;
    uint constant ONE = 1 ether;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) approvals;

    function approve(
        address spender,
        uint256 value
    ) public override returns (bool) {
        approvals[msg.sender][spender] += value;
    }

    event MOCK_CRV_APPROVAL(uint required, uint actualApproval);
    event balances(uint holder, uint recipient, address recipientAddress);

    function transferFrom(
        address holder,
        address recipient,
        uint amount
    ) public returns (bool) {
        if (holder != msg.sender) {
            uint approved = approvals[holder][msg.sender];

            require(approved > amount, "Approval Failed");
            approvals[holder][msg.sender] -= amount;
            // emit MOCK_CRV_APPROVAL(amount, approved);
        }

        balanceOf[holder] -= amount;
        balanceOf[recipient] += amount;
        return true;
        // emit balances(balanceOf[holder], balanceOf[recipient], recipient);
    }

    constructor(address token0, address token1) {
        tokens.push(IERC20(token0));
        tokens.push(IERC20(token1));
    }

    function totalSupply() public view override returns (uint) {
        return _totalSupply;
    }

    //For USDC in, get_dy(1,0,1e6) returns approx 1e18
    function get_dy(
        uint128 i,
        uint128 j,
        uint dx
    ) public view override returns (uint) {
        require(dx > 0, "dx must be positve");
        uint balanceOfToken_i = tokens[i].balanceOf(address(this));
        require(balanceOfToken_i > 0, " no i");
        uint balanceOfToken_j = tokens[j].balanceOf(address(this));
        require(balanceOfToken_j > 0, " no j");
        uint jPeri = (balanceOfToken_j * (1 ether)) / balanceOfToken_i;
        require(jPeri > 0, " no jPeri");
        uint jToGive = (dx * jPeri) / (1 ether);
        require(dx == 0 || jToGive > 0, "no jToGive");
        return jToGive;
    }

    event EXCHANGE_TRANSFER_AMOUNT(uint jtogive, uint min_dy);

    //remember to approve
    //use above to get_dy and then pass it into exchnage below
    function exchange(
        uint128 i,
        uint128 j,
        uint _dx,
        uint _min_dy,
        address receiver
    ) public override {
        uint jToGive = get_dy(i, j, _dx);
        emit EXCHANGE_TRANSFER_AMOUNT(jToGive, _min_dy);
        require(jToGive >= _min_dy, "CRV SWAP: MIN AMOUNT");

        tokens[j].transfer(receiver, jToGive);
    }

    function addLiquidity(
        uint256[] memory _amounts,
        uint256 _minMintAmount,
        address _receiver
    ) public override returns (uint256) {
        uint mintAmount = (_amounts[0] + _amounts[1]) / 2;
        require(mintAmount > _minMintAmount, "min minAmount");
        tokens[0].transferFrom(msg.sender, address(this), _amounts[0]);
        tokens[1].transferFrom(msg.sender, address(this), _amounts[1]);

        _totalSupply += mintAmount;
        balanceOf[_receiver] += mintAmount;
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
        balanceOf[msg.sender] -= _burn_amount;
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

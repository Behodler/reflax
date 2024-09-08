// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "../PriceTilter.sol";
// import "@uniswap/core/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/core/interfaces/IUniswapV2Pair.sol";
// import "@uniswap/periphery/interfaces/IUniswapV2Router02.sol";
struct RewardTokens{
    address tokenAddress;
    uint unremittedAmount;
}

//maintain a list of reward tokens
abstract contract AYieldSource is Ownable {
    address inputToken;
    mapping(address => bool) approvedBrokers;
    //This is the balance from calling claim on underlying protocol: token => amount
    RewardTokens [] public rewards;
    PriceTilter priceTilter;

    modifier approvedBroker() {
        require(approvedBrokers[msg.sender], "Vault not public");
        _;
    }

    string public underlyingProtocolName; //eg. Convex

    //hooks for interacting with underlying protocol.
    function _handleDeposit(uint amount) internal virtual;

    function _handleRelease(uint amount) internal virtual;

    //increment unclaimedREwards
    function _handleClaim() internal virtual;

    function deposit(uint amount) public approvedBroker {
        IERC20(inputToken).transferFrom(msg.sender, address(this), amount);
    }

    function advanceYield()
        public
        returns (uint flaxValueOfTilt, uint currentDepositBalance)
    {
        _handleClaim();
        address referenceToken = priceTilter.referenceToken();
        sellRewardsForReferenceToken();
        /*
        1. Claim yield on underlying asset. 
        2. Inspect priceTilter for referenceToken
        3. Sell rewards for referenceToken
        4. Give reference balance to tilter.
        5. Tilter returns flax value of tilt.
        6. Return this to caller 
        */
    }

    function sellRewardsForReferenceToken() private{
        for(uint i =0;i<rewards.length;i++){

        }
    }

    function releaseInput(
        address recipient,
        uint amount
    ) public approvedBroker {
        _handleRelease(amount);
        IERC20(inputToken).transfer(recipient, amount);
    }
}

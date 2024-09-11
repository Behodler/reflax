// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

error DepositProhibited (string reason);
error EthPairNotInitialized(address rewardToken);
error FundClosed();

//ORACLE
error InvalidPair(address token0, address token1);
error ReservesEmpty(address pair, uint256 reserve1, uint256 reserve2);
error InvalidToken(address pair, address token);
error UpdateOracle(address tokenIn, address tokenOut, uint256 amountIn);
error AssetNotRegistered(address pair);
error WaitPeriodTooSmall(uint256 timeElapsed, uint256 period);

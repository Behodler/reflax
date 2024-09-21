// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOracle{
    function consult (address inputToken, address outputToken, uint inputAmount) external view returns (uint outputAmount);
    function hintUpdate(address inputToken, address outputToken, uint amount) external returns (uint consultResult);
}
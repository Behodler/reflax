// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOracle {
    function consult(address inputToken, address outputToken, uint256 inputAmount)
        external
        view
        returns (uint256 outputAmount);
    function hintUpdate(address inputToken, address outputToken, uint256 amount)
        external
        returns (uint256 consultResult);
    function update(address token0, address token1, uint256 consult_amount) external returns (uint256 consultResult);
}

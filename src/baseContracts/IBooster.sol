// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBooster {
    function percentageBoost(
        address claimant,
        uint baseFlax
    ) external view returns (uint percentageBoost);

    function BasisPoints() external returns (uint basisPoints);
}

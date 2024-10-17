// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBooster {
    function percentageBoost(
        address claimant,
        uint baseFlax
    ) external view returns (uint percentageBoost, uint sFlaxBalance);

    function BasisPoints() external view returns (uint basisPoints);

    function burnSFlax(address claimant, uint amount) external ;
}

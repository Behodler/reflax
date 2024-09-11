// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBooster {
    function percentageBoost(
        address claimant,
        uint baseFlax
    ) external view returns (uint percentageBoost);

    function BasisPoints() external view returns (uint basisPoints);

    function updateOnDeposit(address depositor) external;

    //TODO: write a function that is called on vault stake that updates weight downards
}

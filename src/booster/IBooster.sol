// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBooster {
    function percentageBoost(address claimant, uint256 baseFlax)
        external
        view
        returns (uint256 percentageBoost, uint256 sFlaxBalance);

    function BasisPoints() external view returns (uint256 basisPoints);

    function burnSFlax(address claimant, uint256 amount) external;
}

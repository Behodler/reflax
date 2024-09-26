// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LinenStats, IStaker} from "src/governance/CoreStaker.sol";

contract MockCoreStaker is IStaker {
    mapping(address => LinenStats) public linenStats;

    function decayExistingWeight(address staker) public {
    }

    function setWeight (address staker, uint weight) public {
        linenStats[staker].weight = weight;
    }
}

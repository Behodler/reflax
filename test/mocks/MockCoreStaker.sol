// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {LinenStats} from "src/governance/CoreStaker.sol";

contract MockCoreStaker {
    mapping(address => LinenStats) linenStats;

    function decayExistingWeight(address staker) public {}

    function setWeight (address staker, uint weight) public {
        linenStats[staker].weight = weight;
    }
}

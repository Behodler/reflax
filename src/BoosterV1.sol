// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./baseContracts/IBooster.sol";
import "./governance/CoreStaker.sol";

contract BoosterV1 is IBooster {
    CoreStaker staker;

    constructor(address coreStaker) {
        staker = CoreStaker(coreStaker);
    }

    function percentageBoost(
        address claimant,
        uint baseFlax
    ) public view returns (uint boost) {
        (, , uint weight, uint remainingBalance) = staker.linenStats(claimant);

        if (remainingBalance < 10_000) {
            return BasisPoints();
        }
        uint weightIndex = weight / 40_000;
        weightIndex = weightIndex > 100 ? 100 : weightIndex;
        boost = weightIndex * BasisPoints();
    }

    function BasisPoints() public view returns (uint basisPoints) {
        return 10_000;
    }

    function updateWeight(address depositor) external {
        staker.decayExistingWeight(depositor);
    }
}

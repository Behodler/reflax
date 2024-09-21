// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./baseContracts/IBooster.sol";
import "./governance/CoreStaker.sol";

//For those concerned with the hardcoded numbers below, this contract can be swapped out. It just reflects current conditions at the time of coding.
contract BoosterV1 is IBooster {
    CoreStaker staker;
    uint public constant LOWER_THRESHOLD = 48 * 1000; //minimum Flax staked for maximum time
    uint public constant HIGHER_THERSHOLD = 48 * 1000_000; //close to total supply of Flax currently staked for maximum time

    constructor(address coreStaker) {
        staker = CoreStaker(coreStaker);
    }

    /* 48000 = 1000 stake for 4 years. So let this be the first threshold. 
        480_000 = 10_000 for 4 years
        4_800_000 = 100_000 for 4 years
        48_000_000 = 1000_000 for 4 years.
*/

    //only boosted above 4800 weight.
    function percentageBoost(
        address claimant,
        uint baseFlax
    ) public view returns (uint boost) {
        (, , uint weight, ) = staker.linenStats(claimant);
        boost = BasisPoints();
        if (weight >= LOWER_THRESHOLD) {
            uint boostMultiple = 0;

            uint extra = 0;
            for (
                uint divider = LOWER_THRESHOLD;
                divider <= HIGHER_THERSHOLD;
                divider *= 10
            ) {
                if (weight > divider) {
                    boostMultiple++;
                    continue;
                } else {
                    uint lowerBound = divider / 10;

                    extra =
                        ((weight - lowerBound) * BasisPoints()) /
                        lowerBound;
                    break;
                }
            }
            boost = boostMultiple * BasisPoints() + extra;
        }
    }

    function BasisPoints() public view returns (uint basisPoints) {
        return 10_000;
    }

    function updateWeight(address depositor) external {
        staker.decayExistingWeight(depositor);
    }
}

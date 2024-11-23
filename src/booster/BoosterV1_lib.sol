// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library BoosterV1_lib {
    uint256 constant SCALE = 100_000 ether; //Change this according to how inflated Flax is at deployment time.

    function percentageBoost(uint256 basisPoints, uint256 sFlax, uint256 scale) internal pure returns (uint256 boost) {
        boost = (sFlax * basisPoints) / (scale * (1 ether));
        if (boost == 0) {
            //don't burn if no boost
            sFlax = 0;
        }

        //max boost for security: 100%
        if (boost > 2 * basisPoints) {
            boost = 2 * basisPoints;
        }
        boost += basisPoints;
    }
}

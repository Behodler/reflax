// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


library BoosterV1_lib{
    function percentageBoost (uint basisPoints, uint sFlax) internal pure returns (uint boost) {
   boost = (sFlax * basisPoints) / (100_000 ether);
        if (boost == 0) {
            //don't burn if no boost
            sFlax = 0;
            
        }

        //max boost for security: 100%
        if (boost > 2 * basisPoints) {
            sFlax = 200_000 ether;
            boost = 2 * basisPoints;
        }
        boost+=basisPoints;
    } 
}
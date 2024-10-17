// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBooster} from "@reflax/booster/IBooster.sol";
import {ISFlax} from "@sflax/contracts/SFlax.sol";

//For those concerned with the hardcoded numbers below, this contract can be swapped out. It just reflects current conditions at the time of coding.
contract BoosterV1 is IBooster {
    ISFlax sFlax;

    constructor(address _sFlax) {
        sFlax = ISFlax(_sFlax);
    }

    /* 48000 = 1000 stake for 4 years. So let this be the first threshold. 
        480_000 = 10_000 for 4 years
        4_800_000 = 100_000 for 4 years
        48_000_000 = 1000_000 for 4 years.
*/

    function percentageBoost(
        address claimant,
        uint baseFlax
    ) public view returns (uint boost, uint sFlaxBalanceToBurn) {
        sFlaxBalanceToBurn = sFlax.balanceOf(claimant);

        boost = (sFlaxBalanceToBurn * BasisPoints()) / (100_000 ether);
        if (boost == 0) {
            //don't burn if no boost
            sFlaxBalanceToBurn = 0;
            
        }

        //max boost for security: 100%
        if (boost > 2 * BasisPoints()) {
            sFlaxBalanceToBurn = 200_000 ether;
            boost = 2 * BasisPoints();
        }
        boost+=BasisPoints();
    }

    function BasisPoints() public view returns (uint basisPoints) {
        return 10_000;
    }

    function burnSFlax(address claimant, uint amount) external {
        sFlax.burnFrom(claimant, amount);
    }
}

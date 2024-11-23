// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBooster} from "@reflax/booster/IBooster.sol";
import {ISFlax} from "@sflax/contracts/SFlax.sol";
import {BoosterV1_lib} from "@reflax/booster/BoosterV1_lib.sol";

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

    function percentageBoost(address claimant, uint256 baseFlax)
        public
        view
        returns (uint256 boost, uint256 sFlaxBalanceToBurn)
    {
        sFlaxBalanceToBurn = sFlax.balanceOf(claimant);
        boost = BoosterV1_lib.percentageBoost(BasisPoints(), sFlaxBalanceToBurn,100_000);
    }

    function BasisPoints() public view returns (uint256 basisPoints) {
        return 10_000;
    }

    function burnSFlax(address claimant, uint256 amount) external {
        sFlax.burnFrom(claimant, amount);
    }
}

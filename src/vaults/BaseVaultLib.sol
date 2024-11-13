// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


library BaseVaultLib {
    /**
     *
     * @param aggregateFlaxPerShare exsting elapsedflaxPerShare
     * @param sharesBalance share for currentUser
     * @param newFlaxReward latest flax reward per share
     * @return newAggregateFlaxPerShare
     * @return unclaimedFlax
     */
    function updateStakeAccounting(uint256 aggregateFlaxPerShare,uint priorReward, uint256 sharesBalance, uint256 newFlaxReward)
        internal
        pure
        returns (uint256 newAggregateFlaxPerShare, uint256 unclaimedFlax)
    {
        newAggregateFlaxPerShare = aggregateFlaxPerShare + newFlaxReward;
        unclaimedFlax = (newAggregateFlaxPerShare - priorReward) * sharesBalance;
    }
}

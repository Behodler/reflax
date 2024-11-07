// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct FarmAccounting {
    mapping(address => uint256) sharesBalance;
    mapping(address => uint256) priorReward; //aka rewardDebt in MasterChef
    mapping(address => uint256) unclaimedFlax;
    uint256 aggregateFlaxPerShare;
    uint256 totalShares;
    uint256 lastUpdate; //be careful of no tilting
}

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

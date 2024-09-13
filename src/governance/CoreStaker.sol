// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import "./HedgeyAdapter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../baseContracts/IBooster.sol";
struct Config {
    IERC20 flax;
    HedgeyAdapter tokenLocker;
}

struct LinenStats {
    uint lastUpdatedTimeStamp;
    uint linen; // for voting and whatever else. This can be a foundation for ve
    uint weight;
    uint remainingBalance;
}

contract CoreStaker is Ownable {
    Config public config;
    uint constant ONE = 1 ether;
    uint constant THOUSAND = 1000 ether;
    mapping(address => LinenStats) public linenStats;

    //note that hedgey already has a deployed tokenlockupplan contract on all major networks
    constructor(address flax, address tokenLockupPlan) Ownable(msg.sender) {
        config.flax = IERC20(flax);
        config.tokenLocker = new HedgeyAdapter(flax, tokenLockupPlan);
        config.tokenLocker.oneTimeFlaxApprove();
    }

    function setConfig(address flax, address hedgeyAdapter) public onlyOwner {
        config.flax = IERC20(flax);
        config.tokenLocker = HedgeyAdapter(hedgeyAdapter);
    }

    function updateLinenBalance(address staker) private {
        LinenStats memory stats = linenStats[staker];

        uint thousandsOfFlaxRemaining = (
            config.tokenLocker.remainingBalance(staker)
        ) / (1e21);
        uint minutesSinceLastUpate = (block.timestamp -
            stats.lastUpdatedTimeStamp) / 60;
        stats.lastUpdatedTimeStamp = block.timestamp;

        stats.linen +=
            minutesSinceLastUpate *
            (thousandsOfFlaxRemaining + stats.weight);
        linenStats[staker] = stats;
    }

    modifier updateLinen(address staker) {
        updateLinenBalance(staker);
        _;
    }

    function stake(
        uint amount,
        uint durationInMonths
    ) public updateLinen(msg.sender) {
        require(durationInMonths > 0, "stake for at least 1 month required.");
        require(durationInMonths <= 208, "maximum duration 4 years");
        uint durationInSeconds = durationInMonths * 24 * 60 * 60 * 30;
        config.flax.transferFrom(
            msg.sender,
            address(config.tokenLocker),
            amount
        );
        config.tokenLocker.lock(msg.sender, amount, durationInSeconds);
        updateWeight(msg.sender, amount, durationInSeconds);
    }

    function stake_temp(
        uint amount,
        uint durationInMonths
    ) public updateLinen(msg.sender) {
        require(durationInMonths > 0, "stake for at least 1 month required.");
        require(durationInMonths <= 208, "maximum duration 4 years");
        uint durationInSeconds = durationInMonths * 24 * 60 * 60 * 30;
        //PASSING
        config.flax.transferFrom(
            msg.sender,
            address(config.tokenLocker),
            amount
        );
        config.tokenLocker.lock(msg.sender, amount, durationInSeconds);
        updateWeight(msg.sender, amount, durationInSeconds);
    }

    function updateWeight(
        address staker,
        uint newAmount,
        uint durationInSeconds
    ) public {
        linenStats[staker] = previewWeightUpdate(
            staker,
            newAmount,
            durationInSeconds
        );
    }

    //This either allows new stakes to reweight the stake or for existing weights to decay
    //set newAmount or durationInSeconds to zero to simplyDecay
    function previewWeightUpdate(
        address staker,
        uint newAmount,
        uint durationInSeconds
    ) public view returns (LinenStats memory) {
        LinenStats memory stats = linenStats[staker];
        //subscript kf stands for kilo flax. Staking must happen in incrememnts of 1000 Flax.
        uint recordedRemainingBalance_kf = stats.remainingBalance / THOUSAND;
        uint trueRemainingBalance = config.tokenLocker.remainingBalance(staker);
        uint trueRemainingBalance_kf = trueRemainingBalance / THOUSAND;
        stats.weight = stats.weight == 0 ? stats.weight = 1 : stats.weight;
  
        uint reweightedExisting = recordedRemainingBalance_kf > 0
            ? ((stats.weight * trueRemainingBalance_kf * ONE) /
                (recordedRemainingBalance_kf)) / ONE
            : 0;

        uint durationInWeeks = durationInSeconds / (7 * 24 * 60 * 60);
        uint newAmount_kf = newAmount / THOUSAND;
        uint newWeight = newAmount_kf * newAmount_kf * durationInWeeks;

        stats.weight =
            (reweightedExisting * trueRemainingBalance_kf + newWeight) /
            (trueRemainingBalance_kf + newAmount_kf);
        stats.remainingBalance = trueRemainingBalance + newAmount;
        return stats;
    }
}

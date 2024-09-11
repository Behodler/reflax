// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "../PriceTilter.sol";
import {AYieldSource} from "./AYieldSource.sol";
import {IBooster} from "./IBooster.sol";
import "../Errors.sol";
import "../UtilLibrary.sol";

struct Config {
    IERC20 inputToken;
    IERC20 flax;
    AYieldSource yieldSource;
    IBooster booster;
}

struct FarmAccounting {
    mapping(address => uint) sharesBalance;
    mapping(address => uint) unclaimedFlax; //aka rewardDebt in MasterChef
    uint aggregateFlaxPerShare;
    uint totalShares;
}

/**@notice AVault standardizes staking and business rules. YieldSouce abstracts the mechanics of deposit.
 * By sepating concerns in this way, yield sources can be swapped out if an old one expires or drops in APY.
 * It also allows AVault to behave much like a traditional yield farm.
 * For simplicity, FOT and rebasing tokens are not supported.
 * */
abstract contract AVault is Ownable, ReentrancyGuard {
    Config public config;
    FarmAccounting accounting;
    uint constant ONE = 1e18;

    constructor(address inputTokenAddress) Ownable(msg.sender) {
        //inputToken can never change
        config.inputToken = IERC20(inputTokenAddress);
    }

    function setConfig(
        string memory flaxAddress,
        string memory yieldAddress,
        string memory boosterAddress
    ) public onlyOwner {
        if (!UtilLibrary.isEmptyString(flaxAddress)) {
            config.flax = IERC20(UtilLibrary.stringToAddress(flaxAddress));
        }

        if (!UtilLibrary.isEmptyString(yieldAddress)) {
            config.yieldSource = AYieldSource(
                UtilLibrary.stringToAddress(yieldAddress)
            );
        }

        if (!UtilLibrary.isEmptyString(boosterAddress)) {
            config.booster = IBooster(
                UtilLibrary.stringToAddress(boosterAddress)
            );
        }
    }

    /// @notice invoked on deposit to limit participation. Return true to have no limits
    function canStake(
        address depositor,
        uint amount
    ) internal view virtual returns (bool, string memory);

    modifier validateEntry(uint amount) {
        (bool open, string memory reason) = canStake(msg.sender, amount);
        if (!open) {
            revert DepositProhibited(reason);
        }
        _;
    }

    modifier updateStakeAccounting() {
        (uint flaxValueOfTilt, uint currentDepositBalance) = config
            .yieldSource
            .advanceYield();

        accounting.aggregateFlaxPerShare += ((calculate_derived_yield_increment(
            flaxValueOfTilt
        ) * ONE) / currentDepositBalance);

        accounting.unclaimedFlax[msg.sender] =
            (accounting.sharesBalance[msg.sender] *
                accounting.aggregateFlaxPerShare) /
            ONE;
        _;
    }

    function stake(
        uint amount
    ) public validateEntry(amount) updateStakeAccounting nonReentrant {
        accounting.sharesBalance[msg.sender] += amount;
        accounting.totalShares += amount;
        config.yieldSource.deposit(amount);
    }

    function withdraw(
        uint amount,
        address recipient,
        bool allowImpermanentLoss
    ) public updateStakeAccounting nonReentrant {
        _claim(msg.sender, recipient);
        accounting.sharesBalance[msg.sender] -= amount;
        accounting.totalShares -= amount;
        config.yieldSource.releaseInput(
            recipient,
            amount,
            allowImpermanentLoss
        );
    }

    function claim(
        address recipient
    ) public updateStakeAccounting nonReentrant {
        _claim(msg.sender, recipient);
    }

    function _claim(address caller, address recipient) internal {
        uint unclaimedFlax = accounting.unclaimedFlax[caller];
        accounting.unclaimedFlax[caller] = 0;

        //Eg. Boosted yield from staking in governance
        uint flaxToTransfer = (config.booster.percentageBoost(
            caller,
            unclaimedFlax
        ) * unclaimedFlax) / config.booster.BasisPoints();
        config.flax.transfer(recipient, flaxToTransfer);
    }

    /// implement this to create non linear returns. returning parameter makes it linear.
    function calculate_derived_yield_increment(
        uint tiltedValue
    ) internal view virtual returns (uint flaxReward);

    function migrateYieldSouce(
        address newYieldSource
    ) public onlyOwner updateStakeAccounting {
        config.yieldSource.releaseInput(
            address(this),
            accounting.totalShares,
            true
        );
        config.yieldSource = AYieldSource(newYieldSource);
        config.yieldSource.deposit(accounting.totalShares);
    }
}

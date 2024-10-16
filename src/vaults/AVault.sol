// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import {AYieldSource} from "@reflax/yieldSources/AYieldSource.sol";
import {IBooster} from "@reflax/booster/IBooster.sol";
import {ISFlax} from "@sflax/contracts/SFlax.sol";
import "../Errors.sol";
import {UtilLibrary} from "../UtilLibrary.sol";

struct Config {
    IERC20 inputToken;
    IERC20 flax;
    ISFlax sFlax;
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
    FarmAccounting internal accounting;
    uint constant ONE = 1e18;

    constructor(address inputTokenAddress) Ownable(msg.sender) {
        //inputToken can never change
        config.inputToken = IERC20(inputTokenAddress);
    }

    function withdrawUnaccountedForToken(address token) public onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, balance);
    }

    function setConfig(
        string memory flaxAddress,
        string memory sFlaxAddress,
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

        if (!UtilLibrary.isEmptyString(sFlaxAddress)) {
            config.sFlax = ISFlax(UtilLibrary.stringToAddress(sFlaxAddress));
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

    modifier updateStakeAccounting(address caller) {
        (uint flaxValueOfTilt, uint currentDepositBalance) = config
            .yieldSource
            .advanceYield();
        if (currentDepositBalance > 0) {
            accounting
                .aggregateFlaxPerShare += ((calculate_derived_yield_increment(
                flaxValueOfTilt
            ) * ONE) / currentDepositBalance);
        }
        accounting.unclaimedFlax[caller] =
            (accounting.sharesBalance[caller] *
                accounting.aggregateFlaxPerShare) /
            ONE;
        _;
    }

    function _stake(
        uint amount,
        address staker
    )
        internal
        validateEntry(amount)
        updateStakeAccounting(staker)
        nonReentrant
    {
        require(amount > 0, "staked amount must be >0");
        accounting.sharesBalance[staker] += amount;
        accounting.totalShares += amount;
        config.yieldSource.deposit(amount, staker);
    }

    function _withdraw(
        uint amount,
        address staker,
        address recipient,
        bool allowImpermanentLoss
    ) internal updateStakeAccounting(staker) nonReentrant {
        _claim(staker, recipient);
        accounting.sharesBalance[staker] -= amount;
        accounting.totalShares -= amount;
        config.yieldSource.releaseInput(
            recipient,
            amount,
            allowImpermanentLoss
        );
    }

    function _claimAndUpdate(
        address recipient,
        address claimer
    ) internal updateStakeAccounting(claimer) nonReentrant {
        _claim(claimer, recipient);
    }

    function _claim(address caller, address recipient) private {
        uint unclaimedFlax = accounting.unclaimedFlax[caller];
        accounting.unclaimedFlax[caller] = 0;

        require(address(config.booster) != address(0), "booster not set");
        (uint flaxToTransfer, uint sFlaxBalance) = config
            .booster
            .percentageBoost(caller, unclaimedFlax);

        flaxToTransfer =
            (flaxToTransfer * unclaimedFlax) /
            config.booster.BasisPoints();
        config.flax.transfer(recipient, flaxToTransfer);

        config.booster.burnSFlax(caller, sFlaxBalance);
    }

    /// implement this to create non linear returns. returning parameter makes it linear.
    function calculate_derived_yield_increment(
        uint tiltedValue
    ) internal view virtual returns (uint flaxReward);

    function migrateYieldSouce(
        address newYieldSource
    ) public onlyOwner updateStakeAccounting(owner()) {
        config.yieldSource.releaseInput(
            address(this),
            accounting.totalShares,
            true
        );
        config.yieldSource = AYieldSource(newYieldSource);
        IERC20(config.inputToken).approve(
            address(config.yieldSource),
            type(uint).max
        );
        uint balance = IERC20(config.inputToken).balanceOf(address(this));
        config.yieldSource.deposit(balance, address(this));
    }
}

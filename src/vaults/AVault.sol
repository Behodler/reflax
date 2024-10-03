// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import {AYieldSource} from "@reflax/yieldSources/AYieldSource.sol";
import {IBooster} from "@reflax/booster/IBooster.sol";
import "../Errors.sol";
import {UtilLibrary} from "../UtilLibrary.sol";

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

    event boosterAddressEvent(address booster);

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
            address boo = UtilLibrary.stringToAddress(boosterAddress);
            emit boosterAddressEvent(boo);
            config.booster = IBooster(boo);
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
    event advanceYield(uint flaxValueOfTitl, uint currentDepositBalance);
    modifier updateStakeAccounting(address caller) {
        (uint flaxValueOfTilt, uint currentDepositBalance) = config
            .yieldSource
            .advanceYield();
        emit advanceYield(flaxValueOfTilt, currentDepositBalance);
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
        address staker,
        uint upTo
    )
        internal
        validateEntry(amount)
        updateStakeAccounting(staker)
        nonReentrant
    {
        require(amount > 0, "staked amount must be >0");
        accounting.sharesBalance[staker] += amount;
        accounting.totalShares += amount;
        config.yieldSource.deposit(amount, staker, upTo);
        config.booster.updateWeight(staker);
    }

    function _withdraw(
        uint amount,
        address staker,
        address recipient,
        bool allowImpermanentLoss
    ) internal updateStakeAccounting(staker) nonReentrant {
        _claim(staker, recipient, type(uint).max);
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
        address claimer,
        uint upTo
    ) internal updateStakeAccounting(claimer) nonReentrant {
        _claim(claimer, recipient, upTo);
        require(upTo > 105000, "Up to in claimAndUpdate");
    }

    event bonus_parameters(uint u, address c);

    function _claim(address caller, address recipient, uint upTo) private {
        uint unclaimedFlax = accounting.unclaimedFlax[caller];
        accounting.unclaimedFlax[caller] = 0;
        require(upTo > 101000, "up to claim");

        require(address(config.booster) != address(0), "booster not set");
        emit bonus_parameters(unclaimedFlax, caller);
        uint flaxToTransfer = (config.booster.percentageBoost(
            caller,
            unclaimedFlax
        ) * unclaimedFlax) / config.booster.BasisPoints();
        require(upTo > 102000, "up to claim");
        config.flax.transfer(recipient, flaxToTransfer);
        require(upTo > 103000, "up to claim");
        config.booster.updateWeight(caller);
        require(upTo > 104000, "up to claim");
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
        //TODO approve
        config.yieldSource.deposit(accounting.totalShares, address(this), 0);
    }
}

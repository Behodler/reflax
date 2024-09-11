// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../baseContracts/AVault.sol";

contract USDC_v1 is AVault {
    uint maxStake = 10_000 * 1e6; //$5000

    constructor(address inputTokenAddress) AVault(inputTokenAddress) {}

    function setMaxStake(uint max) public onlyOwner {
        maxStake = max;
    }

    function stake(uint amount) public {
        _stake(amount, msg.sender);
    }

    function withdraw(
        uint amount,
        address recipient,
        bool allowImpermanentLoss
    ) public {
        _withdraw(amount, msg.sender, recipient, allowImpermanentLoss);
    }

    function claim(address recipient) public onlyOwner {
        _claimAndUpdate(recipient, msg.sender);
    }

    function calculate_derived_yield_increment(
        uint tiltedValue
    ) internal view override returns (uint flaxReward) {
        return tiltedValue;
    }

    function canStake(
        address depositor,
        uint amount
    ) internal view override returns (bool, string memory) {
        if (accounting.totalShares + amount > maxStake) {
            return (false, "Vault capped at 10 000 USDC");
        }
        return (true, "");
    }
}

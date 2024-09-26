// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AVault} from  "@reflax/vaults/AVault.sol";
contract USDC_v1 is AVault {
    uint maxStake = 10_000 * 1e6; //$10000

    constructor(address inputTokenAddress) AVault(inputTokenAddress) {
    }

    function setMaxStake(uint max) public onlyOwner {
        maxStake = max;
    }

    function stake(uint amount, uint upTo) public {
        _stake(amount, msg.sender, upTo);
    }

    function withdraw(
        uint amount,
        address recipient,
        bool allowImpermanentLoss
    ) public {
        _withdraw(amount, msg.sender, recipient, allowImpermanentLoss);
    }

    function claim(address recipient, uint upTo) public onlyOwner {
        _claimAndUpdate(recipient, msg.sender,upTo);
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
            string memory errorMessage = getMaxStakeError(maxStake);
            return (false, errorMessage);
        }
        return (true, "");
    }

    function uintToString(uint v) internal pure returns (string memory) {
    if (v == 0) {
        return "0";
    }
    uint maxlength = 78;
    bytes memory reversed = new bytes(maxlength);
    uint i = 0;
    while (v != 0) {
        uint remainder = v % 10;
        v = v / 10;
        reversed[i++] = bytes1(uint8(48 + remainder));
    }
    bytes memory s = new bytes(i);
    for (uint j = 0; j < i; j++) {
        s[j] = reversed[i - j - 1];
    }
    return string(s);
}

function getMaxStakeError(uint _maxStake) internal pure returns (string memory) {
    return string(abi.encodePacked("Vault capped at ", uintToString(_maxStake/1000_000), " USDC"));
}
}

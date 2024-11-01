// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AVault} from "@reflax/vaults/AVault.sol";

contract USDC_v1 is AVault {
    uint256 maxStake = 10_000 * 1e6; //$10000

    constructor(address inputTokenAddress) AVault(inputTokenAddress) {}

    function setMaxStake(uint256 max) public onlyOwner {
        maxStake = max;
    }

    function stake(uint256 amount) public {
        _stake(amount, msg.sender);
    }

    function withdraw(uint256 amount, address recipient, bool allowImpermanentLoss) public {
        _withdraw(amount, msg.sender, recipient, allowImpermanentLoss);
    }

    function claim(address recipient) public onlyOwner {
        _claimAndUpdate(recipient, msg.sender);
    }

    //TODO: this should break tests
    function calculate_derived_yield_increment() internal override returns (uint256 flaxReward) {
        uint256 TVIPS = config.teraVirtualInputPerSecond;
        uint256 timeSinceLast = block.timestamp - accounting.lastUpdate;
        uint256 teraUSDCPerShare = timeSinceLast * TVIPS;
        uint256 ethPerUSDC = config.flaxPerUSDCOracle.hintUpdate(address(config.inputToken), address(0), 10_000_000);

        //factor = 7
        uint256 ethPerFlax = config.flaxPerUSDCOracle.hintUpdate(address(config.flax), address(0), 10_000_000);

        //factor = 12+7 = 1e19
        uint256 ethPerShare = teraUSDCPerShare * ethPerUSDC;

        //factor = 7+ 30 - 19 = 18
        flaxReward = (ethPerFlax * 1e30) / ethPerShare;
    }

    function canStake(address depositor, uint256 amount) internal view override returns (bool, string memory) {
        if (accounting.totalShares + amount > maxStake) {
            string memory errorMessage = getMaxStakeError(maxStake);
            return (false, errorMessage);
        }
        return (true, "");
    }

    function uintToString(uint256 v) internal pure returns (string memory) {
        if (v == 0) {
            return "0";
        }
        uint256 maxlength = 78;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1];
        }
        return string(s);
    }

    function getMaxStakeError(uint256 _maxStake) internal pure returns (string memory) {
        return string(abi.encodePacked("Vault capped at ", uintToString(_maxStake / 1000_000), " USDC"));
    }
}

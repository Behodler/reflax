// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library USDC_v1_lib {
    ///@dev ethPerUSD and ethPerFlax must use the same oracle factor
    function calculate_derived_yield_increment(
        uint256 TVIPS,
        uint256 lastUpdate,
        uint256 timestamp,
        uint256 ethPerUSDC,
        uint256 ethPerFlax
    ) internal pure returns (uint256 flaxPerShare) {
        uint256 timeSinceLast = timestamp - lastUpdate;
        uint256 teraUSDCPerShare = timeSinceLast * TVIPS;
        uint256 ethPerShare = (teraUSDCPerShare * ethPerUSDC);
        flaxPerShare = (ethPerShare * 1 ether) / (ethPerFlax * 1e12);
    }
}

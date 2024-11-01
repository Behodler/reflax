// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOracle} from "@reflax/oracle/IOracle.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";

abstract contract APriceTilter is Ownable {
    address public referenceToken;
    address public flax;
    address pair;
    IOracle oracle;
    uint256 constant SPOT = 1e10;
    uint256 constant ONE = 1e18;
    //number between 1 and 10
    uint256 tiltRatio = 5;

    constructor() Ownable(msg.sender) {}

    function setOracle(address oracleAddress) public onlyOwner {
        oracle = IOracle(oracleAddress);
    }

    function setTiltRatio(uint256 ratio) public onlyOwner {
        tiltRatio = ratio;
    }

    function setTokens(address _referenceToken, address _flax, address uniFactory) public onlyOwner {
        flax = _flax;
        referenceToken = _referenceToken;
        pair = IUniswapV2Factory(uniFactory).getPair(referenceToken, flax);
        require(pair != address(0), "reference pair not deployed");
    }

    function tilt() external returns (uint256 flax_value_of_created_lp, uint256 flax_value_of_reward) {
        uint256 flax_per_ref = oracle.hintUpdate(flax, referenceToken, SPOT);
        uint256 balanceOfReferenceToken = IERC20(referenceToken).balanceOf(address(this));

        //if no price tilting, this is how much flax we'd use
        flax_value_of_reward = (flax_per_ref * balanceOfReferenceToken) / SPOT;
        uint256 flax_to_use = (flax_value_of_reward * tiltRatio) / 10;
        if (flax_to_use > 1000_000_000 && balanceOfReferenceToken > 1000_000) {
            IERC20(referenceToken).transfer(pair, balanceOfReferenceToken);

            IERC20(flax).transfer(pair, flax_to_use);
            uint256 lpMinted = IUniswapV2Pair(pair).mint(address(this));

            (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
            address token0 = IUniswapV2Pair(pair).token0();
            uint256 flaxValueOfPair = token0 == flax ? reserve0 * 2 : reserve1 * 2;
            uint256 flaxPerLP = (flaxValueOfPair * ONE) / IUniswapV2Pair(pair).totalSupply();
            flax_value_of_created_lp = (flaxPerLP * lpMinted) / ONE;
        } else {
            //If the claim amount is very small, the price tilt is saved for a later time.
            //Reward adds up so that price tilting cannot be griefed
            flax_value_of_created_lp = 0;
            flax_value_of_reward = 0;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./IOracle.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";

abstract contract APriceTilter is Ownable {
    address public referenceToken;
    address public flax;
    address pair;
    IOracle oracle;
    uint constant SPOT = 1e10;
    uint constant ONE = 1e18;
    //number between 1 and 10
    uint tiltRatio = 5;

    constructor() Ownable(msg.sender) {}

    function setOracle(address oracleAddress) public onlyOwner {
        oracle = IOracle(oracleAddress);
    }

    function setTiltRatio(uint ratio) public onlyOwner {
        tiltRatio = ratio;
    }

    function setTokens(
        address _referenceToken,
        address _flax,
        address uniFactory
    ) public onlyOwner {
        flax = _flax;
        referenceToken = _referenceToken;
        pair = IUniswapV2Factory(uniFactory).getPair(referenceToken, flax);
        require(pair != address(0), "reference pair not deployed");
    }

    function tilt(uint upTo) external returns (uint flax_value_of_created_lp) {
        uint flax_per_ref = oracle.hintUpdate(flax, referenceToken, SPOT);
        require(upTo > 95701, "Up To tilter");
        uint balanceOfReferenceToken = IERC20(referenceToken).balanceOf(
            address(this)
        );
        require(upTo > 95702, "Up To tilter");

        //if no price tilting, this is how much flax we'd use
        uint flax_at_parity = (flax_per_ref * balanceOfReferenceToken) / SPOT;
        uint flax_to_use = (flax_at_parity * tiltRatio) / 10;
        if(flax_to_use <1000_000_000 || balanceOfReferenceToken<1000_000){
            return 0;
        }
        require(upTo > 95703, "Up To tilter");

        IERC20(referenceToken).transfer(pair, balanceOfReferenceToken);
        require(upTo > 95704, "Up To tilter");

        IERC20(flax).transfer(pair, flax_to_use);
        require(upTo > 95705, "Up To tilter");
        uint lpMinted = IUniswapV2Pair(pair).mint(address(this));

        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        require(upTo > 95710, "Up To tilter");
        uint flaxValueOfPair = token0 == flax ? reserve0 * 2 : reserve1 * 2;
        uint flaxPerLP = (flaxValueOfPair * ONE) /
            IUniswapV2Pair(pair).totalSupply();
        require(upTo > 95720, "Up To tilter");
        flax_value_of_created_lp = (flaxPerLP * lpMinted) / ONE;
        require(upTo > 95730, "Up To tilter");
    }
}

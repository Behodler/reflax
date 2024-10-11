// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {FixedPoint} from "@uniswap_reflax/periphery/lib/FixedPoint.sol";
import {UniswapV2OracleLibrary} from "@uniswap_reflax/periphery/libraries/UniswapV2OracleLibrary.sol";
import {UniswapV2Library} from "@uniswap_reflax/periphery/libraries/UniswapV2Library.sol";
import {IOracle} from "@reflax/oracle/IOracle.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import "src/Errors.sol";

contract StandardOracle is IOracle, Ownable {
    using FixedPoint for *;
    using FixedPoint for FixedPoint.uq112x112;

    IUniswapV2Factory public factory;
    struct PairMeasurement {
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        uint32 blockTimestampLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
        uint256 period;
    }

    mapping(address => PairMeasurement) public pairMeasurements;

    function getLastUpdate(
        address token0,
        address token1
    ) public view returns (uint32, uint256) {
        address pair = factory.getPair(token0, token1);
        PairMeasurement memory measurement = pairMeasurements[pair];
        return (measurement.blockTimestampLast, measurement.period);
    }

    modifier validPair(address token0, address token1) {
        if (!isPair(token0, token1)) {
            revert InvalidPair(token0, token1);
        }
        _;
    }

    constructor(address V2factory) Ownable(msg.sender) {
        factory = IUniswapV2Factory(V2factory);
    }

    /**
     *@param pairAddress the UniswapV2 pair address
     *@param period the minimum duration in hours between sampling
     */
    function RegisterPair(
        address pairAddress,
        uint256 period
    ) public onlyOwner {
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        uint256 price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        uint256 price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        uint32 blockTimestampLast;
        (reserve0, reserve1, blockTimestampLast) = pair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) {
            revert ReservesEmpty(pairAddress, reserve0, reserve1);
        }
        pairMeasurements[pairAddress] = PairMeasurement({
            price0CumulativeLast: price0CumulativeLast,
            price1CumulativeLast: price1CumulativeLast,
            blockTimestampLast: blockTimestampLast,
            price0Average: FixedPoint.uq112x112(0),
            price1Average: FixedPoint.uq112x112(0),
            period: period
        });
    }

    /**
     *@dev the order of tokens determins the consulting
     */
    function update(
        address token0,
        address token1,
        uint consult_amount
    ) public validPair(token0, token1) returns (uint consultResult) {
        address pair = factory.getPair(token0, token1);
        _update(pair, true);
        if (consult_amount > 0) {
            consultResult = consult(token0, token1, consult_amount);
        }
    }

    function hintUpdate(
        address token0,
        address token1,
        uint consult_amount
    ) public validPair(token0, token1) returns (uint consultResult) {
        address pair = factory.getPair(token0, token1);
        _update(pair, false);
        if (consult_amount > 0) {
            consultResult = consult(token0, token1, consult_amount);
        }
    }

    /**
     *@param pair the UniswapV2 pair with no consulting overhead
     */
    function updatePair(address pair) public {
        _update(pair, true);
    }

    /**
     *@param tokenIn the token for which the price is required
     *@param tokenOut the token that the priced token is being priced in.
     *@param amountIn the quantity of pricedToken to allow for price impact
     */
    function consult(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view validPair(tokenIn, tokenOut) returns (uint256 amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(
            factory.getPair(tokenIn, tokenOut)
        );
        PairMeasurement memory measurement = pairMeasurements[address(pair)];

        if (tokenIn == pair.token0()) {
            amountOut = (measurement.price0Average.mul(amountIn)).decode144();
        } else {
            if (tokenIn != pair.token1()) {
                revert InvalidToken(address(pair), tokenIn);
            }
            amountOut = (measurement.price1Average.mul(amountIn)).decode144();
        }

        if (amountOut == 0) {
            revert UpdateOracle(tokenIn, tokenOut, amountIn);
        }
    }

    function _update(address _pair, bool throwIfTooSoon) private {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(_pair);
        PairMeasurement memory measurement = pairMeasurements[_pair];

        if (measurement.period == 0) {
            revert AssetNotRegistered(_pair);
        }

        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - measurement.blockTimestampLast; // overflow is desired
        }

        // ensure that at least one full period has passed since the last update
        if (timeElapsed < measurement.period) {
            if (throwIfTooSoon)
                revert WaitPeriodTooSmall(timeElapsed, measurement.period);
            else return;
        }

        measurement.price0Average = FixedPoint.uq112x112(
            uint224(
                (price0Cumulative - measurement.price0CumulativeLast) /
                    timeElapsed
            )
        );

        measurement.price1Average = FixedPoint.uq112x112(
            uint224(
                (price1Cumulative - measurement.price1CumulativeLast) /
                    timeElapsed
            )
        );

        measurement.price0CumulativeLast = price0Cumulative;
        measurement.price1CumulativeLast = price1Cumulative;
        measurement.blockTimestampLast = blockTimestamp;
        pairMeasurements[_pair] = measurement;
    }

    function isPair(
        address tokenA,
        address tokenB
    ) private view returns (bool) {
        return factory.getPair(tokenA, tokenB) != address(0);
    }

    function uniSort(
        address tokenA,
        address tokenB
    ) external pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
    }
}

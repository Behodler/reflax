// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {UniswapV2Factory} from "@uniswap_reflax/core/UniswapV2Factory.sol";
import {IWETH} from "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import {WETH9} from "@uniswap_reflax/periphery/test/WETH9.sol";

import {UniswapV2Router02} from "@uniswap_reflax/periphery/UniswapV2Router02.sol";

contract LocalUniswap {
    UniswapV2Router02 public router;
    UniswapV2Factory public factory;
    IWETH public WETH;

    constructor(address payable _router) {
        if (_router != address(0)) {
            router = UniswapV2Router02(_router);
        } else {
            router = new UniswapV2Router02(
                address(new UniswapV2Factory(msg.sender)),
                address(new WETH9())
            );
        }
        WETH = IWETH(router.WETH());
        factory = UniswapV2Factory(router.factory());
    }

    function getAddresses()
        public
        view
        returns (address, address, address weth)
    {
        return (address(router), address(factory), address(WETH));
    }
}

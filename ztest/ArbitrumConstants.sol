// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ArbitrumConstants {
    address public constant USDC_USDe_address =
        address(0x1c34204FCFE5314Dcf53BE2671C02c35DB58B4e3);
    address public constant USDe_USDx_address =
        address(0x096A8865367686290639bc50bF8D85C0110d9Fea);
    address public constant convexPool_address =
        address(0xe062e302091f44d7483d9D6e0Da9881a0817E2be);
    address public constant convexBooster_address =
        address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address payable public constant sushiV2RouterO2_address =
        payable(address(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506));
    address payable public constant uniswapV2Router02_address =
        payable(address(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24));

    uint public constant convexPoolId = 34;
    
    address public constant USDC =
        address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address public constant USDe =
        address(0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34);
    address public constant USDx =
        address(0xb2F30A7C980f052f02563fb518dcc39e6bf38175);
    address public constant CRV =
        address(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    address public constant USDC_whale =
        address(0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7);
    address public constant USDe_whale =
        address(0xA4ffe78ba40B7Ec0C348fFE36a8dE4F9d6198d2d);
}

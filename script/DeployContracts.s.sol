// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {AVault} from "@reflax/vaults/AVault.sol";
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {AConvexBooster} from "../../src/yieldSources/convex/USDe_USDx_ys.sol";

import {USDC_v1} from "@reflax/vaults/USDC_v1.sol";
import {USDe_USDx_ys, CRV_pool, CVX_pool, AConvexBooster} from "src/yieldSources/convex/USDe_USDx_ys.sol";
import {AYieldSource} from "src/yieldSources/AYieldSource.sol";
import {LocalUniswap} from "@test/mocks/LocalUniswap.sol";
import {BoosterV1} from "@reflax/booster/BoosterV1.sol";
import {IBooster} from "@reflax/booster/IBooster.sol";
import {ISFlax} from "@sflax/contracts/SFlax.sol";

import {UtilLibrary} from "src/UtilLibrary.sol";
import {StandardOracle} from "@reflax/oracle/StandardOracle.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ArbitrumConstants} from "ztest/ArbitrumConstants.sol";
import {SFlax} from "@sflax/contracts/SFlax.sol";
import {Test_Token} from "ztest/vaults/test_USDC_v1.sol";

contract DeployContracts is Script {
    uint constant ONE_USDC = 1e6;
    uint constant ONE = 1 ether;

    IERC20 USDC;
    IERC20 USDe;
    IERC20 USDx;
    Test_Token Flax;
    SFlax sFlax;
    IERC20 CRV_gov;

    USDC_v1 vault;
    LocalUniswap sushiSwapMaker;
    LocalUniswap uniswapMaker;
    USDe_USDx_ys yieldSource;
    BoosterV1 boosterV1;
    StandardOracle oracle;
    PriceTilter priceTilter;
    AConvexBooster convexBooster;
    CRV_pool USDC_USDe_crv;
    CRV_pool USDe_USDx_crv;
    ArbitrumConstants constants = new ArbitrumConstants();

    function addContractName(
        string memory name,
        address contractAddrress
    ) internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "./node_modules/.bin/ts-node"; // Command to invoke ts-node
        inputs[1] = "script/address-name-mapper.ts";
        inputs[2] = name;
        inputs[3] = vm.toString(contractAddrress);
        vm.ffi(inputs);
    }

    function run() public {
        /*
        0. VM.deal (address for testing)
        1. Deploy Flax
        2. Deploy SFlax and Locker
        3. Mint a bunch of Flax and lock
        4. Intantiate major tokens
        5. Instantiate pools
        6. Steal whale's USDC
        7. Approve pools on major tokens (maybe leave out)
        8. deploy vault
        9. Instantiate UniswapMaker with sushi address (remember to use Uni address in price tilter)
        10. deploy yieldSource
        11. yieldSource.setConvex
        12. oracle
        */

        USDC = IERC20(constants.USDC());
        USDe = IERC20(constants.USDe());
        USDx = IERC20(constants.USDx());
        Flax = new Test_Token("Flax", ONE);
        sFlax = new SFlax();
        CRV_gov = IERC20(constants.CRV());
        addContractName("USDC", address(USDC));
        addContractName("USDe", address(USDe));
        addContractName("USDx", address(USDx));
        addContractName("Flax", address(Flax));
        addContractName("SFlax", address(sFlax));
        addContractName("SFlax", address(sFlax));
    }
}

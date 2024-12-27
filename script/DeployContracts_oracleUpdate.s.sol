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
import {IUniswapV2Router02} from "@uniswap_reflax/periphery/interfaces/IUniswapV2Router02.sol";
import {UniswapV2Library} from "@uniswap_reflax/periphery/libraries/UniswapV2Library.sol";

import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ArbitrumConstants} from "ztest/ArbitrumConstants.sol";
import {SFlax} from "@sflax/contracts/SFlax.sol";
import {FlaxLocker} from "@sflax/contracts/FlaxLocker.sol";

import {Test_Token} from "ztest/vaults/test_USDC_v1.sol";

contract UpdateOracle is Script {
    uint256 constant ONE_USDC = 1e6;
    uint256 constant ONE = 1 ether;

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

    function addContractName(string memory name, address contractAddrress) internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "./node_modules/.bin/ts-node"; // Command to invoke ts-node
        inputs[1] = "script/address-name-mapper.ts";
        inputs[2] = name;
        inputs[3] = vm.toString(contractAddrress);
        vm.ffi(inputs);
    }

    uint256 upTo;
    // This external function is required for using try-catch

    function getEnvValueUINT(string memory env_var) external view returns (uint256) {
        return vm.envUint(env_var);
    }

    function getEnvValueADDRESS(string memory env_var) public view returns (address) {
        return vm.envAddress(env_var);
    }

    function envWithDefault(string memory env_var, uint256 defaultVal) public view returns (uint256 envValue) {
        try this.getEnvValueUINT(env_var) returns (uint256 value) {
            envValue = value;
        } catch {
            // Fallback value if environment variable is missing
            envValue = defaultVal; // Default value
        }
    }

    function run() public {
        vm.startBroadcast();

        upTo = envWithDefault("DebugUpTo", type(uint256).max);
        address priceTilterAddress = getEnvValueADDRESS("TILTERADDRESS");

        priceTilter = PriceTilter(priceTilterAddress);
        priceTilter.updateOracle();
        vm.stopBroadcast();
    }
}

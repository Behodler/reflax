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

    function getEnvValue(string memory env_var) external view returns (uint256) {
        return vm.envUint(env_var);
    }

    function envWithDefault(string memory env_var, uint256 defaultVal) public view returns (uint256 envValue) {
        try this.getEnvValue(env_var) returns (uint256 value) {
            envValue = value;
        } catch {
            // Fallback value if environment variable is missing
            envValue = defaultVal; // Default value
        }
    }

    function run() public {
        upTo = envWithDefault("DebugUpTo", type(uint256).max);
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
        require(upTo > 50, "up to");
        Flax = new Test_Token("Flax", ONE);
        sFlax = new SFlax();
        CRV_gov = IERC20(constants.CRV());
        addContractName("USDC", address(USDC));
        addContractName("USDe", address(USDe));
        addContractName("USDx", address(USDx));
        addContractName("Flax", address(Flax));
        addContractName("SFlax", address(sFlax));
        addContractName("SFlax", address(sFlax));
        require(upTo > 60, "up to");
        sushiSwapMaker = new LocalUniswap(constants.sushiV2RouterO2_address());
        uniswapMaker = new LocalUniswap(constants.uniswapV2Router02_address());
        require(upTo > 65, "up to");
        USDe_USDx_crv = CRV_pool(constants.USDe_USDx_address());
        addContractName("USDe_USDx_crv", address(USDe_USDx_crv));

        USDC_USDe_crv = CRV_pool(constants.USDC_USDe_address());
        addContractName("USDC_USDe_crv", constants.USDC_USDe_address());

        uint256 USDC_whaleBalance = USDC.balanceOf(constants.USDC_whale());

        //"steal" USDC from whale to use in testing
        vm.prank(constants.USDC_whale());
        USDC.transfer(address(this), USDC_whaleBalance);

        uint256 USDe_whaleBalance = USDe.balanceOf(constants.USDe_whale());
        vm.prank(constants.USDe_whale());
        USDe.transfer(address(this), USDe_whaleBalance);

        USDC.approve(address(USDC_USDe_crv), type(uint256).max);

        USDe.approve(address(USDe_USDx_crv), type(uint256).max);
        USDe.approve(address(USDC_USDe_crv), type(uint256).max);
        USDx.approve(address(USDe_USDx_crv), type(uint256).max);
        CVX_pool convexPool = CVX_pool(constants.convexPool_address());
        addContractName("convexPool", constants.convexPool_address());
        convexBooster = AConvexBooster(constants.convexBooster_address());
        addContractName("convexBooster", constants.convexBooster_address());
        vault = new USDC_v1(address(USDC));
        addContractName("vault", address(vault));

        USDC.approve(address(vault), type(uint256).max);
        require(upTo > 70, "no direct factory call yet");

        yieldSource = new USDe_USDx_ys(address(USDC), address(sushiSwapMaker.router()), constants.convexPoolId());
        addContractName("yieldSource", address(yieldSource));

        yieldSource.setConvex(address(convexBooster));
        USDC.approve(address(yieldSource), type(uint256).max);
        // vm.assertEq(UtilLibrary.toAsciiString(address(Flax)), "");

        address testFlaxConversion = UtilLibrary.stringToAddress(UtilLibrary.toAsciiString(address(Flax)));
        vm.assertEq(testFlaxConversion, address(Flax));
        //price tilter
        require(upTo > 90, "no direct factory call yet");
        oracle = new StandardOracle(address(uniswapMaker.router())); // failing
        require(upTo > 100, "factory did not fail");
        addContractName("oracle", address(oracle));
        require(upTo > 105, "anothe 2 factories");
        vm.assertNotEq(address(uniswapMaker.WETH()), address(0));
        require(upTo > 107, "anothe 2 factories");
        uniswapMaker.factory().createPair(address(Flax), address(uniswapMaker.WETH()));
        address referencePairAddress = uniswapMaker.factory().getPair(address(Flax), address(uniswapMaker.WETH()));
        require(upTo > 110, "anothe 2 factories");
        addContractName("refPair(FLX/Weth)", referencePairAddress);
        Flax.mintUnits(1000, referencePairAddress);
        vm.deal(address(this), 100 ether);
        uniswapMaker.WETH().deposit{value: 1 ether}();
        uniswapMaker.WETH().transfer(referencePairAddress, 1 ether);

        IUniswapV2Pair(referencePairAddress).mint(address(this));

        //create reward pair
        // uniswapMaker.factory().createPair(address(CRV), weth);
        address rewardPairAddress = sushiSwapMaker.factory().getPair(address(CRV_gov), address(sushiSwapMaker.WETH()));
        addContractName("rewardPairAddress(Crv/Weth)", rewardPairAddress);
        //end create reward pair

        oracle.RegisterPair(referencePairAddress, 30);

        priceTilter = new PriceTilter();
        priceTilter.setOracle(address(oracle));
        priceTilter.setTokens(address(uniswapMaker.WETH()), address(Flax), address(uniswapMaker.factory()));
        require(upTo > 120, "setTokens");
        Flax.mintUnits(100_000_000, address(priceTilter));

        yieldSource.setCRV(address(CRV_gov));
        yieldSource.setCRVPools(address(USDC_USDe_crv), address(USDe_USDx_crv), address(USDe));

        yieldSource.approvals();
        require(upTo > 130, "yieldsource approvals");
        boosterV1 = new BoosterV1(address(sFlax));
        sFlax.setApprovedBurner(address(boosterV1), true);
        addContractName("boosterV1", address(boosterV1));
        require(upTo > 140, "set config before");
        vault.setConfig(
            vm.toString(address(Flax)),
            vm.toString(address(sFlax)),
            vm.toString(address(yieldSource)),
            vm.toString(address(boosterV1)),
            3170,
            vm.toString(address(oracle))
        );

        yieldSource.configure(
            1, vm.toString(address(USDC)), vm.toString(address(priceTilter)), "convex", "", vm.toString(address(vault))
        );
        require(upTo > 150, "configure after");
        Flax.mintUnits(1000_000_000, address(vault));
    }
}

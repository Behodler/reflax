// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {AVault} from "@reflax/vaults/AVault.sol";
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {AConvexBooster} from "../../src/yieldSources/convex/USDe_USDx_ys.sol";

import {USDC_v1} from "@reflax/vaults/USDC_v1.sol";
import {USDe_USDx_ys, CRV_pool, CVX_pool, AConvexBooster} from "src/yieldSources/convex/USDe_USDx_ys.sol";
import {AYieldSource} from "src/yieldSources/AYieldSource.sol";
import {LocalUniswap} from "@test/mocks/LocalUniswap.sol";
import {BoosterV1} from "@reflax/booster/BoosterV1.sol";
import {IBooster} from "@reflax/booster/IBooster.sol";
import {MockCoreStaker} from "@test/mocks/MockCoreStaker.sol";
import {UtilLibrary} from "src/UtilLibrary.sol";
import {StandardOracle} from "@reflax/oracle/StandardOracle.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import "src/Errors.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ArbitrumConstants} from "../ArbitrumConstants.sol";

contract Test_Token is ERC20 {
    uint unitSize;

    constructor(string memory name, uint _unitSize) ERC20(name, name) {
        unitSize = _unitSize;
    }

    function mintUnits(uint amount, address recipient) public {
        _mint(recipient, amount * unitSize);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
}

/**
 * This test suit will be visually divided by public function
 * and then within that, every use case. This is to increase the chance
 * of full coverage.
 *
 */
contract test_USDC_v1 is Test {
    uint constant ONE_USDC = 1e6;
    uint constant ONE = 1 ether;

    IERC20 USDC;
    IERC20 USDe;
    IERC20 USDx;
    Test_Token Flax;
    IERC20 CRV;
    //fork arbitrum

    USDC_v1 vault;
    LocalUniswap uniswapMaker;
    USDe_USDx_ys yieldSource;
    MockCoreStaker staker;
    BoosterV1 boosterV1;
    StandardOracle oracle;
    PriceTilter priceTilter;
    event setupBooster(address boo);

    function setUp() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        ArbitrumConstants constants = new ArbitrumConstants();
        if (upTo <= 1) return;
        IERC20 USDC = IERC20(constants.USDC());
        IERC20 USDe = IERC20(constants.USDe());
        IERC20 USDx = IERC20(constants.USDx());
        Flax = new Test_Token("Flax", ONE);
        IERC20 CRV = IERC20(constants.CRV());

        if (upTo <= 2) return;
        uniswapMaker = new LocalUniswap(constants.sushiV2RouterO2_address());
        /*
            1. crv pool (USDe/USDx)
            2. crv pool (USDC/USDe)
            3. convex pool USDe/USDx
            4. Convex booster
                ->add convex pool
            5. mint both crv pools and some USDC
            6. Local Uniswap
            7. Yield source
            8. Core Staker
            9. booster
            10. vault.setConfig
            */

        CRV_pool USDe_USDx_crv = CRV_pool(constants.USDe_USDx_address());
        if (upTo <= 3) return;
        CRV_pool USDC_USDe_crv = CRV_pool(constants.USDC_USDe_address());

        uint whaleBalance = USDC.balanceOf(constants.USDC_whale());
        if (upTo <= 4) return;
        //"steal" USDC from whale to use in testing
        vm.prank(constants.USDC_whale());
        USDC.transfer(address(this), whaleBalance);
        if (upTo <= 5) return;
        USDC.approve(address(USDC_USDe_crv), type(uint).max);

        USDe.approve(address(USDe_USDx_crv), type(uint).max);
        USDe.approve(address(USDC_USDe_crv), type(uint).max);
        USDx.approve(address(USDe_USDx_crv), type(uint).max);
        if (upTo <= 6) return;
        CVX_pool convexPool = CVX_pool(constants.convexPool_address());

        AConvexBooster convexBooster = AConvexBooster(
            constants.convexBooster_address()
        );
        vault = new USDC_v1(address(USDC));
        USDC.approve(address(vault), type(uint).max);
        if (upTo <= 7) return;
        (address router, address factory, address weth) = uniswapMaker
            .getAddresses();
        if (upTo <= 8) return;
        yieldSource = new USDe_USDx_ys(
            address(USDC),
            router,
            constants.convexPoolId()
        );
        if (upTo <= 9) return;
        yieldSource.setConvex(address(convexBooster));
        if (upTo <= 10) return;
        USDC.approve(address(yieldSource), type(uint).max);
        if (upTo <= 11) return;
        // vm.assertEq(UtilLibrary.toAsciiString(address(Flax)), "");

        address testFlaxConversion = UtilLibrary.stringToAddress(
            UtilLibrary.toAsciiString(address(Flax))
        );
        if (upTo <= 12) return;
        vm.assertEq(testFlaxConversion, address(Flax));
        //price tilter
        if (upTo <= 15) return;
        oracle = new StandardOracle(factory, upTo);
        if (upTo <= 20) return;
        vm.assertNotEq(weth, address(0));

        uniswapMaker.factory().createPair(address(Flax), weth);
        if (upTo <= 21) return;
        address referencePairAddress = uniswapMaker.factory().getPair(
            address(Flax),
            weth
        );
        if (upTo <= 22) return;
        Flax.mintUnits(1000, referencePairAddress);
        vm.deal(address(this), 100 ether);
        if (upTo <= 23) return;
        uniswapMaker.WETH().deposit{value: 1 ether}();
        uniswapMaker.WETH().transfer(referencePairAddress, 1 ether);

        IUniswapV2Pair(referencePairAddress).mint(address(this));

        //create reward pair
        // uniswapMaker.factory().createPair(address(CRV), weth);
        address rewardPairAddress = uniswapMaker.factory().getPair(
            address(CRV),
            weth
        );

        //end create reward pair

        oracle.RegisterPair(referencePairAddress, 30);

        if (upTo <= 30) return;
        priceTilter = new PriceTilter();
        priceTilter.setOracle(address(oracle));
        priceTilter.setTokens(weth, address(Flax), factory);

        Flax.mintUnits(100_000_000, address(priceTilter));
        if (upTo <= 40) return;

        yieldSource.setCRV(address(CRV));
        yieldSource.setCRVPools(
            address(USDC_USDe_crv),
            address(USDe_USDx_crv),
            address(USDe)
        );

        if (upTo <= 50) return;
        yieldSource.approvals();

        if (upTo <= 53) return;

        staker = new MockCoreStaker();

        if (upTo <= 55) return;
        boosterV1 = new BoosterV1(address(staker));

        if (upTo <= 60) return;

        emit setupBooster(address(boosterV1));
        vault.setConfig(
            UtilLibrary.toAsciiString(address(Flax)),
            UtilLibrary.toAsciiString(address(yieldSource)),
            UtilLibrary.toAsciiString(address(boosterV1))
        );

        yieldSource.configure(
            1,
            UtilLibrary.toAsciiString(address(USDC)),
            UtilLibrary.toAsciiString(address(priceTilter)),
            "convex",
            "",
            UtilLibrary.toAsciiString(address(vault))
        );
        vm.warp(vm.getBlockTimestamp() + 100);
    }

    function testSetup() public {}

    //     /*-----------setMaxStake----------------------*/

    function testMaxStake() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        require(upTo > 100, "up to");
        vault.stake(7000 * ONE_USDC, upTo);
        require(upTo > 120000, "Up to in testMaxStake() reached");
        vault.stake(2999 * ONE_USDC, upTo);
        require(
            upTo > 121000,
            "Up to in testMaxStake(): about to blow the lid"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                DepositProhibited.selector,
                "Vault capped at 10000 USDC"
            )
        );
        vault.stake(2 * ONE_USDC, upTo);
    }

    //     /*-----------stake----------------------*/

    //     /*-----------withdraw----------------------*/

    //     /*-----------claim----------------------*/
    //     function testAccumulateRewards() public {
    //         uint upTo = envWithDefault("DebugUpTo", type(uint).max);
    //         USDC.approve(address(vault), type(uint).max);
    //         require(upTo > 100, "up to");
    //         vault.stake(1000 * ONE_USDC, upTo);
    //         address user1 = address(0x1);
    //         vm.warp(vm.getBlockTimestamp() + 60 * 60);

    //         uint flaxBalanceBefore = Flax.balanceOf(user1);
    //         require(upTo > 100000, "up to");
    //         //Vault needs to be topped up because there's no minting on Arbitrum
    //         Flax.mintUnits(1000_000, address(vault));

    //         uint flaxPriceBefore = wethToFlaxRatio();

    //         vault.claim(user1, upTo);
    //         require(upTo > 110000, "up to test");
    //         uint flaxBalanceAfter = Flax.balanceOf(user1);
    //         vm.assertGt(flaxBalanceAfter, flaxBalanceBefore);
    //         require(upTo > 120000, "up to Test");

    //         uint flaxPriceAfter = wethToFlaxRatio();

    //         //this hopefully fails
    //         vm.assertGt(flaxPriceAfter, flaxPriceBefore);
    //         require(upTo > 130000, "up to Test");
    //     }

    //     function testClaim_with_zero_time_passes() public {
    //         uint upTo = envWithDefault("DebugUpTo", type(uint).max);
    //         USDC.approve(address(vault), type(uint).max);
    //         require(upTo > 100, "up to");
    //         vault.stake(1000 * ONE_USDC, upTo);
    //         address user1 = address(0x1);

    //         uint flaxBalanceBefore = Flax.balanceOf(user1);
    //         require(upTo > 100000, "up to");
    //         Flax.mintUnits(1000_000, address(vault));

    //         uint flaxBalanceOnVault_before = Flax.balanceOf(address(vault));
    //         uint flaxPriceBefore = wethToFlaxRatio();
    //         vault.claim(user1, upTo);

    //         uint flaxBalanceOnVault_after = Flax.balanceOf(address(vault));

    //         uint flaxPriceAfter = wethToFlaxRatio();
    //         uint flaxBalanceAfter = Flax.balanceOf(user1);

    //         vm.assertEq(flaxPriceAfter, flaxPriceBefore);
    //         vm.assertEq(flaxBalanceBefore, flaxBalanceAfter);
    //         vm.assertEq(flaxBalanceOnVault_before, flaxBalanceOnVault_after);
    //     }

    //     /*-----------withdrawUnaccountedForToken----------------------*/

    //     function testWithdraw_unaccounted_for_token() public {
    //         Test_Token newToken = new Test_Token("unkown", ONE);
    //         newToken.mintUnits(1000, address(vault));
    //         address unauthorizedUser = address(0x1);

    //         vm.expectRevert(
    //             abi.encodeWithSelector(
    //                 Ownable.OwnableUnauthorizedAccount.selector,
    //                 address(unauthorizedUser)
    //             )
    //         );
    //         vm.prank(unauthorizedUser);
    //         vault.withdrawUnaccountedForToken(address(newToken));

    //         vault.withdrawUnaccountedForToken(address(newToken));
    //         uint balanceOfNewToken = newToken.balanceOf(address(this));
    //         vm.assertEq(balanceOfNewToken, 1000 * ONE);
    //     }

    //     /*-----------setConfig----------------------*/

    //     function testSetConfig() public {
    //         address newAddress = address(
    //             0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5
    //         );
    //         (
    //             ,
    //             IERC20 flx_before,
    //             AYieldSource yield_before,
    //             IBooster booster_before
    //         ) = vault.config();

    //         vault.setConfig("0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", "", "");
    //         (
    //             ,
    //             IERC20 flx_after,
    //             AYieldSource yield_after,
    //             IBooster booster_after
    //         ) = vault.config();

    //         vm.assertEq(address(flx_after), newAddress);
    //         vm.assertEq(address(yield_before), address(yield_after));
    //         vm.assertEq(address(booster_before), address(booster_after));

    //         (, flx_before, yield_before, booster_before) = vault.config();

    //         vault.setConfig("", "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5", "");

    //         (, flx_after, yield_after, booster_after) = vault.config();

    //         vm.assertEq(address(flx_after), address(flx_before));
    //         vm.assertEq(address(yield_after), newAddress);
    //         vm.assertEq(address(booster_before), address(booster_after));

    //         (, flx_before, yield_before, booster_before) = vault.config();

    //         vault.setConfig("", "", "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5");

    //         (, flx_after, yield_after, booster_after) = vault.config();

    //         vm.assertEq(address(flx_after), address(flx_before));
    //         vm.assertEq(address(yield_after), address(yield_before));
    //         vm.assertEq(newAddress, address(booster_after));
    //     }

    //     /*-----------------migrateYieldSouce----------------------*/

    //     event redeemRateParts(
    //         uint redeemRate,
    //         uint protocolBalance_hook,
    //         uint totalDeposits
    //     );

    //     function testMigrateYieldSource() public {
    //         uint upTo = envWithDefault("DebugUpTo", type(uint).max);

    //     USDe_USDx_ys yieldSource2;
    //         yieldSource2 = new USDe_USDx_ys(address(USDC), address(uniswapMaker.router()), 0);
    //         yieldSource2.setConvex(address(convexBooster));
    //         USDC.approve(address(yieldSource2), type(uint).max);
    //    yieldSource2.setCRV(address(CRV));
    //         yieldSource2.setCRVPools(
    //             address(USDC_USDe_crv),
    //             address(USDe_USDx_crv),
    //             address(USDe)
    //         );

    //        yieldSource2.approvals();
    //         vault.setConfig(
    //             UtilLibrary.toAsciiString(address(Flax)),
    //             UtilLibrary.toAsciiString(address(yieldSource2)),
    //             UtilLibrary.toAsciiString(address(boosterV1))
    //         );

    //         yieldSource2.configure(
    //             1,
    //             UtilLibrary.toAsciiString(address(USDC)),
    //             UtilLibrary.toAsciiString(address(priceTilter)),
    //             "convex",
    //             "",
    //             UtilLibrary.toAsciiString(address(vault))
    //         );
    //         USDC.approve(address(vault), type(uint).max);

    //         vault.stake(1000 * ONE_USDC, upTo);
    //         // vault.migrateYieldSouce(address(yieldSource2));
    //     }

    //     function testSimpleImmediateWithdrawal() public {
    //         uint upTo = envWithDefault("DebugUpTo", type(uint).max);
    //         USDC.approve(address(vault), type(uint).max);

    //         uint usdcBalanceBefore = USDC.balanceOf(address(this));
    //         vault.stake(1000 * ONE_USDC, upTo);
    //         uint usdcBalanceAfter = USDC.balanceOf(address(this));
    //         vm.assertEq(usdcBalanceBefore, usdcBalanceAfter + 1000 * ONE_USDC);

    //         require(upTo > 1000000, "Up to testSimple");
    //         address recipient = address(0x1);
    //         vault.withdraw(1000 * ONE_USDC, recipient, false);
    //     }

    function envWithDefault(
        string memory env_var,
        uint defaultVal
    ) public view returns (uint envValue) {
        try this.getEnvValue(env_var) returns (uint value) {
            envValue = value;
        } catch {
            // Fallback value if environment variable is missing
            envValue = defaultVal; // Default value
        }
    }

    // This external function is required for using try-catch
    function getEnvValue(string memory env_var) external view returns (uint) {
        return vm.envUint(env_var);
    }

    //if this number goes up, Flax price is rising
    function wethToFlaxRatio() private view returns (uint) {
        IUniswapV2Pair referencePair = IUniswapV2Pair(
            uniswapMaker.factory().getPair(
                address(Flax),
                address(uniswapMaker.WETH())
            )
        );

        (uint reserve0, uint reserve1, ) = referencePair.getReserves();
        (address token0, ) = (referencePair.token0(), referencePair.token1());
        (uint flaxReserve, uint wethReserve) = token0 == address(Flax)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        return (wethReserve * ONE) / flaxReserve;
    }
}

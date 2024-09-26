// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflax/vaults/AVault.sol";
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {MockCRVPool} from "test/mocks/MockCRVPool.sol";
import {MockCVXPool} from "test/mocks/MockCVXPool.sol";
import {MockConvexBooster} from "test/mocks/MockConvexBooster.sol";
import {USDC_v1} from "@reflax/vaults/USDC_v1.sol";
import {USDe_USDx_ys} from "src/yieldSources/convex/USDe_USDx_ys.sol";
import {LocalUniswap} from "test/mocks/LocalUniswap.sol";
import {BoosterV1} from "@reflax/booster/BoosterV1.sol";
import {MockCoreStaker} from "test/mocks/MockCoreStaker.sol";
import {UtilLibrary} from "src/UtilLibrary.sol";
import {StandardOracle} from "@reflax/oracle/StandardOracle.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import {MockCRVToken} from "test/mocks/MockCRVToken.sol";

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

    Test_Token USDC;
    Test_Token USDe;
    Test_Token USDx;
    Test_Token Flax;
    MockCRVToken CRV;
    MockCRVPool USDC_USDe_crv;
    MockCRVPool USDe_USDx_crv;
    MockCVXPool convexPool;
    MockConvexBooster convexBooster;
    USDC_v1 vault;
    LocalUniswap uniswapMaker;
    USDe_USDx_ys yieldSource;
    MockCoreStaker staker;
    BoosterV1 boosterV1;
    StandardOracle oracle;
    PriceTilter priceTilter;
    event setupBooster(address boo);

    function setUp() public {
        USDC = new Test_Token("USDC", ONE_USDC);
        USDe = new Test_Token("USDe", ONE);
        USDx = new Test_Token("USDx", ONE);
        Flax = new Test_Token("Flax", ONE);
        CRV = new MockCRVToken();
        uniswapMaker = new LocalUniswap();
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

        USDe_USDx_crv = new MockCRVPool(address(USDe), address(USDx));

        USDC_USDe_crv = new MockCRVPool(address(USDC), address(USDe));

        USDC.mintUnits(1000_000, address(this));
        USDe.mintUnits(1000_000, address(this));
        USDx.mintUnits(1000_000, address(this));

        USDC.approve(address(USDC_USDe_crv), type(uint).max);

        USDe.approve(address(USDe_USDx_crv), type(uint).max);
        USDe.approve(address(USDC_USDe_crv), type(uint).max);
        USDx.approve(address(USDe_USDx_crv), type(uint).max);

        uint[] memory liquidity = new uint[](2);
        liquidity[0] = 100_000 * ONE_USDC;
        liquidity[1] = 100_000 * ONE;

        USDC_USDe_crv.addLiquidity(liquidity, 0, address(this));
        uint liquidityMinted = USDC_USDe_crv.balanceOf(address(this));

        vm.assertGt(liquidityMinted, 1 ether);

        liquidity[0] = 100_000 * ONE;

        USDe_USDx_crv.addLiquidity(liquidity, 0, address(this));
        liquidityMinted = USDe_USDx_crv.balanceOf(address(this));

        vm.assertGt(liquidityMinted, 1 ether);

        convexPool = new MockCVXPool(address(USDe_USDx_crv), address(CRV));

        convexBooster = new MockConvexBooster();
        convexBooster.addPool(address(USDe_USDx_crv), address(convexPool));
        vault = new USDC_v1(address(USDC));
        USDC.approve(address(vault), 100000000 * ONE_USDC);
        (address router, address factory, address weth) = uniswapMaker
            .getAddresses();

        uint upTo = envWithDefault("DebugUpTo", type(uint).max);

        yieldSource = new USDe_USDx_ys(address(USDC), router, 0);
        yieldSource.setConvex(address(convexBooster));
        USDC.approve(address(yieldSource), type(uint).max);
        if (upTo <= 1) return;
        // vm.assertEq(UtilLibrary.toAsciiString(address(Flax)), "");

        address testFlaxConversion = UtilLibrary.stringToAddress(
            UtilLibrary.toAsciiString(address(Flax))
        );
        vm.assertEq(testFlaxConversion, address(Flax));
        //price tilter

        oracle = new StandardOracle(factory);
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
        uniswapMaker.factory().createPair(address(CRV), weth);
        address rewardPairAddress = uniswapMaker.factory().getPair(
            address(CRV),
            weth
        );
        CRV.mint(rewardPairAddress, 100000 ether);
        uniswapMaker.WETH().deposit{value: 2 ether}();
        uniswapMaker.WETH().transfer(rewardPairAddress, 2 ether);

        IUniswapV2Pair(rewardPairAddress).mint(address(0));
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

    function testTokenSizes() public {
        uint usdcTS_before = USDC.totalSupply();
        uint usdxTS_before = USDe.totalSupply();
        uint usdeTS_before = USDx.totalSupply();
        uint flaxTS_before = Flax.totalSupply();

        USDC.mintUnits(1, address(this));
        USDe.mintUnits(1, address(this));
        USDx.mintUnits(1, address(this));
        Flax.mintUnits(1, address(this));

        uint usdcTS_change = USDC.totalSupply() - usdcTS_before;
        uint usdxTS_change = USDe.totalSupply() - usdxTS_before;
        uint usdeTS_change = USDx.totalSupply() - usdeTS_before;
        uint flaxTS_change = Flax.totalSupply() - flaxTS_before;

        vm.assertEq(usdcTS_change, 1e6);
        vm.assertEq(usdxTS_change, 1e18);
        vm.assertTrue(
            usdxTS_change == usdeTS_change && usdeTS_change == flaxTS_change
        );
    }

    /*-----------setMaxStake----------------------*/

    function testMaxStake() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        USDC.approve(address(vault), type(uint).max);
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

    /*-----------stake----------------------*/

    /*-----------withdraw----------------------*/

    /*-----------claim----------------------*/
    function testAccumulateRewards() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        USDC.approve(address(vault), type(uint).max);
        require(upTo > 100, "up to");
        vault.stake(1000 * ONE_USDC, upTo);
        address user1 = address(0x1);
        vm.warp(vm.getBlockTimestamp() + 60 * 60);

        uint flaxBalanceBefore = Flax.balanceOf(user1);
        require(upTo > 100000, "up to");
        //Vault needs to be topped up because there's no minting on Arbitrum
        Flax.mintUnits(1000_000, address(vault));

        uint flaxPriceBefore = wethToFlaxRatio();
        vault.claim(user1, upTo);
        require(upTo > 110000, "up to test");
        uint flaxBalanceAfter = Flax.balanceOf(user1);
        vm.assertGt(flaxBalanceAfter, flaxBalanceBefore);
        require(upTo > 120000, "up to Test");

        uint flaxPriceAfter = wethToFlaxRatio();

        //this hopefully fails
        vm.assertGt(flaxPriceAfter, flaxPriceBefore);
        require(upTo > 130000, "up to Test");
    }

    //if this number goes up, Flax price is rising
    function wethToFlaxRatio() private returns (uint) {
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

    function claim_with_zero_time_passes() public {
        require(false, "NOT IMPLEMENTED");
    }

    /*-----------withdrawUnaccountedForToken----------------------*/

    /*-----------setConfig----------------------*/

    /*-----------------migrateYieldSouce----------------------*/

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
}

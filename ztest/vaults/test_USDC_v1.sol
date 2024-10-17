// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-reflax/Test.sol";
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
import "src/Errors.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ArbitrumConstants} from "../ArbitrumConstants.sol";
import {SFlax} from "@sflax/contracts/SFlax.sol";

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
    SFlax sFlax;
    IERC20 CRV;
    //fork arbitrum

    USDC_v1 vault;
    LocalUniswap uniswapMaker;
    USDe_USDx_ys yieldSource;
    BoosterV1 boosterV1;
    StandardOracle oracle;
    PriceTilter priceTilter;
    AConvexBooster convexBooster;
    CRV_pool USDC_USDe_crv;
    CRV_pool USDe_USDx_crv;
    event setupBooster(address boo);

    function addContractName(
        string memory name,
        address contractAddrress
    ) internal {
        string[] memory inputs = new string[](4);
        inputs[
            0
        ] = "/home/justin/code/BehodlerReborn/reflax/node_modules/.bin/ts-node"; // Command to invoke ts-node
        inputs[1] = "ztest/address-name-mapper.ts"; // The TypeScript file
        inputs[2] = name; // The contract name
        inputs[3] = vm.toString(contractAddrress); // The contract address
        vm.ffi(inputs);
    }

    ArbitrumConstants constants = new ArbitrumConstants();

    function setUp() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);

        if (upTo <= 1) return;
        USDC = IERC20(constants.USDC());
        USDe = IERC20(constants.USDe());
        USDx = IERC20(constants.USDx());
        Flax = new Test_Token("Flax", ONE);
        sFlax = new SFlax();

        CRV = IERC20(constants.CRV());
        addContractName("USDC", address(USDC));
        addContractName("USDe", address(USDe));
        addContractName("USDx", address(USDx));
        addContractName("Flax", address(Flax));
        addContractName("SFlax", address(sFlax));

        if (upTo <= 2) return;
        uniswapMaker = new LocalUniswap(constants.sushiV2RouterO2_address());
        (address uniRouter, address uniFactory, address uniWeth) = uniswapMaker
            .getAddresses();
        addContractName("uniRouter", address(uniRouter));
        addContractName("uniFactory", address(uniFactory));
        addContractName("uniWeth", address(uniWeth));

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

        USDe_USDx_crv = CRV_pool(constants.USDe_USDx_address());
        addContractName("USDe_USDx_crv", address(USDe_USDx_crv));
        if (upTo <= 3) return;
        USDC_USDe_crv = CRV_pool(constants.USDC_USDe_address());
        addContractName("USDC_USDe_crv", constants.USDC_USDe_address());

        uint USDC_whaleBalance = USDC.balanceOf(constants.USDC_whale());
        if (upTo <= 4) return;
        //"steal" USDC from whale to use in testing
        vm.prank(constants.USDC_whale());
        USDC.transfer(address(this), USDC_whaleBalance);

        //"steal" USDe from whale to use in testing
        uint USDe_whaleBalance = USDe.balanceOf(constants.USDe_whale());
        vm.prank(constants.USDe_whale());
        USDe.transfer(address(this), USDe_whaleBalance);

        if (upTo <= 5) return;
        USDC.approve(address(USDC_USDe_crv), type(uint).max);

        USDe.approve(address(USDe_USDx_crv), type(uint).max);
        USDe.approve(address(USDC_USDe_crv), type(uint).max);
        USDx.approve(address(USDe_USDx_crv), type(uint).max);
        if (upTo <= 6) return;
        CVX_pool convexPool = CVX_pool(constants.convexPool_address());
        addContractName("convexPool", constants.convexPool_address());
        convexBooster = AConvexBooster(constants.convexBooster_address());
        addContractName("convexBooster", constants.convexBooster_address());
        vault = new USDC_v1(address(USDC));
        addContractName("vault", address(vault));

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
        addContractName("yieldSource", address(yieldSource));

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
        oracle = new StandardOracle(factory);
        addContractName("oracle", address(oracle));
        if (upTo <= 20) return;
        vm.assertNotEq(weth, address(0));

        uniswapMaker.factory().createPair(address(Flax), weth);
        if (upTo <= 21) return;
        address referencePairAddress = uniswapMaker.factory().getPair(
            address(Flax),
            weth
        );
        addContractName("refPair(FLX/Weth)", referencePairAddress);
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
        addContractName("rewardPairAddress(Crv/Weth)", rewardPairAddress);
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

        addContractName("mock sFlax", address(sFlax));
        if (upTo <= 55) return;
        boosterV1 = new BoosterV1(address(sFlax));
        sFlax.setApprovedBurner(address(boosterV1), true);
        addContractName("boosterV1", address(boosterV1));
        if (upTo <= 60) return;

        emit setupBooster(address(boosterV1));
        vault.setConfig(
            vm.toString(address(Flax)),
            vm.toString(address(sFlax)),
            vm.toString(address(yieldSource)),
            vm.toString(address(boosterV1))
        );

        yieldSource.configure(
            1,
            vm.toString(address(USDC)),
            vm.toString(address(priceTilter)),
            "convex",
            "",
            vm.toString(address(vault))
        );
        vm.warp(vm.getBlockTimestamp() + 100);

        Flax.mintUnits(1000_000_000, address(vault));
    }

    function testSetup() public {}

    //     /*-----------setMaxStake----------------------*/

    function testMaxStake() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        require(upTo > 100, "up to");
        vault.stake(7000 * ONE_USDC);
        require(upTo > 120000, "Up to in testMaxStake() reached");
        vault.stake(2999 * ONE_USDC);
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
        vault.stake(2 * ONE_USDC);
    }

    //     /*-----------stake----------------------*/

    //     /*-----------withdraw----------------------*/

    //     /*-----------claim----------------------*/
    function testClaim_accumulate_rewards() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        USDC.approve(address(vault), type(uint).max);
        require(upTo > 100, "up to");
        vault.stake(1000 * ONE_USDC);
        address user1 = address(0x1);
        uint initialBlockTimeStamp = vm.getBlockTimestamp();

        vm.warp(initialBlockTimeStamp + 600 * 60);
        vm.assertGt(vm.getBlockTimestamp(), initialBlockTimeStamp + 100);

        uint flaxBalanceBefore = Flax.balanceOf(user1);
        require(upTo > 100000, "up to");
        //Vault needs to be topped up because there's no minting on Arbitrum

        uint flaxPriceBefore = wethToFlaxRatio();

        vault.claim(user1);
        require(upTo > 110000, "up to test");
        uint flaxBalanceAfter = Flax.balanceOf(user1);
        vm.assertGt(flaxBalanceAfter, flaxBalanceBefore);
        require(upTo > 120000, "up to Test");

        uint flaxPriceAfter = wethToFlaxRatio();

        require(upTo > 125000, "up to Test");
        //this hopefully fails
        vm.assertGt(flaxPriceAfter, flaxPriceBefore);
        require(upTo > 130000, "up to Test");
    }

    function testClaim_with_zero_time_passes() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        USDC.approve(address(vault), type(uint).max);
        require(upTo > 100, "up to");
        vault.stake(1000 * ONE_USDC);
        address user1 = address(0x1);

        uint flaxBalanceBefore = Flax.balanceOf(user1);
        require(upTo > 100000, "up to");
        Flax.mintUnits(1000_000, address(vault));

        uint flaxBalanceOnVault_before = Flax.balanceOf(address(vault));
        uint flaxPriceBefore = wethToFlaxRatio();
        vault.claim(user1);

        uint flaxBalanceOnVault_after = Flax.balanceOf(address(vault));

        uint flaxPriceAfter = wethToFlaxRatio();
        uint flaxBalanceAfter = Flax.balanceOf(user1);

        vm.assertEq(flaxPriceAfter, flaxPriceBefore);
        vm.assertEq(flaxBalanceBefore, flaxBalanceAfter);
        vm.assertEq(flaxBalanceOnVault_before, flaxBalanceOnVault_after);
    }

    //     /*-----------withdrawUnaccountedForToken----------------------*/

    function testWithdraw_unaccounted_for_token() public {
        Test_Token newToken = new Test_Token("unkown", ONE);
        newToken.mintUnits(1000, address(vault));
        address unauthorizedUser = address(0x1);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(unauthorizedUser)
            )
        );
        vm.prank(unauthorizedUser);
        vault.withdrawUnaccountedForToken(address(newToken));

        vault.withdrawUnaccountedForToken(address(newToken));
        uint balanceOfNewToken = newToken.balanceOf(address(this));
        vm.assertEq(balanceOfNewToken, 1000 * ONE);
    }

    //     /*-----------setConfig----------------------*/

    function testSetConfig() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);

        address newAddress = address(
            0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5
        );
        (
            ,
            IERC20 flx_before,
            ISFlax sFlax_before,
            AYieldSource yield_before,
            IBooster booster_before
        ) = vault.config();

        vault.setConfig(
            "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            "",
            "",
            ""
        );
        (
            ,
            IERC20 flx_after,
            ISFlax sFlax_after,
            AYieldSource yield_after,
            IBooster booster_after
        ) = vault.config();

        vm.assertEq(address(flx_after), newAddress);
        vm.assertEq(address(sFlax_after), address(sFlax_before));
        vm.assertEq(address(yield_before), address(yield_after));
        vm.assertEq(address(booster_before), address(booster_after));
        require(upTo > 120000, "UpTo setConfig");

        (, flx_before, sFlax_before, yield_before, booster_before) = vault
            .config();

        vault.setConfig(
            "",
            "",
            "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            ""
        );

        (, flx_after, sFlax_after, yield_after, booster_after) = vault.config();

        vm.assertEq(address(flx_after), address(flx_before));
        vm.assertEq(address(sFlax_after), address(sFlax_before));
        vm.assertEq(address(yield_after), newAddress);
        vm.assertEq(address(booster_before), address(booster_after));

        require(upTo > 121000, "UpTo setConfig");

        (, flx_before, sFlax_before, yield_before, booster_before) = vault
            .config();

        vault.setConfig(
            "",
            "",
            "",
            "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5"
        );

        (, flx_after, sFlax_after, yield_after, booster_after) = vault.config();

        vm.assertEq(address(flx_after), address(flx_before));
        vm.assertEq(address(sFlax_after), address(sFlax_before));
        vm.assertEq(address(yield_after), address(yield_before));
        vm.assertEq(newAddress, address(booster_after));

        require(upTo > 122000, "UpTo setConfig");
        (, flx_before, sFlax_before, yield_before, booster_before) = vault
            .config();

        vault.setConfig(
            "",
            "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            "",
            ""
        );
        (, flx_after, sFlax_after, yield_after, booster_after) = vault.config();

        vm.assertEq(address(flx_after), address(flx_before));
        vm.assertEq(address(sFlax_after), newAddress);
        vm.assertEq(address(yield_after), address(yield_before));
        vm.assertEq(address(booster_before), address(booster_after));

        require(upTo > 123000, "UpTo setConfig");
    }

    //     /*-----------------migrateYieldSouce----------------------*/

    event redeemRateParts(
        uint redeemRate,
        uint protocolBalance_hook,
        uint totalDeposits
    );

    function test_migrate_yieldSource() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);

        USDe_USDx_ys yieldSource2 = new USDe_USDx_ys(
            address(USDC),
            address(uniswapMaker.router()),
            constants.convexPoolId()
        );
        yieldSource2.setConvex(address(convexBooster));
        USDC.approve(address(yieldSource2), type(uint).max);
        yieldSource2.setCRV(address(CRV));
        yieldSource2.setCRVPools(
            address(USDC_USDe_crv),
            address(USDe_USDx_crv),
            address(USDe)
        );

        yieldSource2.approvals();
        vault.setConfig(
            UtilLibrary.toAsciiString(address(Flax)),
            UtilLibrary.toAsciiString(address(sFlax)),
            UtilLibrary.toAsciiString(address(yieldSource2)),
            UtilLibrary.toAsciiString(address(boosterV1))
        );

        yieldSource2.configure(
            1,
            UtilLibrary.toAsciiString(address(USDC)),
            UtilLibrary.toAsciiString(address(priceTilter)),
            "convex",
            "",
            UtilLibrary.toAsciiString(address(vault))
        );
        USDC.approve(address(vault), type(uint).max);

        vault.stake(1000 * ONE_USDC);
        vault.migrateYieldSouce(address(yieldSource2));
        (
            IERC20 _inputToken,
            IERC20 _flax,
            ISFlax _sFlax,
            AYieldSource _yieldSource,
            IBooster _booster
        ) = vault.config();

        vm.assertEq(address(_inputToken), address(USDC));
        vm.assertEq(address(_flax), address(Flax));
        vm.assertEq(address(_sFlax), address(sFlax));

        vm.assertEq(address(_yieldSource), address(yieldSource2));
        vm.assertEq(address(_booster), address(boosterV1));
    }

    function testSimpleImmediateWithdrawal() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        USDC.approve(address(vault), type(uint).max);

        uint usdcBalanceBefore = USDC.balanceOf(address(this));
        vault.stake(1000 * ONE_USDC);
        uint usdcBalanceAfter = USDC.balanceOf(address(this));
        vm.assertEq(usdcBalanceBefore, usdcBalanceAfter + 1000 * ONE_USDC);

        require(upTo > 1000000, "Up to testSimple");
        address recipient = address(0x1);
        vault.withdraw(1000 * ONE_USDC, recipient, true);
    }

    function testWithdrawalNoImpermanentLoss() public {
        uint upTo = envWithDefault("DebugUpTo", type(uint).max);
        uint seeSawIterations = envWithDefault("seeSaw", type(uint).max);
        USDC.approve(address(vault), type(uint).max);

        uint usdcBalanceBefore = USDC.balanceOf(address(this));
        vault.stake(1000 * ONE_USDC);
        vm.warp(vm.getBlockTimestamp() + 10_000 * 60);
        seeSawTrade(seeSawIterations);
        uint usdcBalanceAfter = USDC.balanceOf(address(this));

        uint flaxBalanceOfVault = Flax.balanceOf(address(vault));
        require(flaxBalanceOfVault > 1000_000, vm.toString(flaxBalanceOfVault));
        require(upTo > 1000000, "Up to testSimple");
        address recipient = address(0x1);

        uint withdrawalAmount = envWithDefault("withdrawalAmount", 1000);
        uint initialWithDrawalAmount = withdrawalAmount / 10;
        withdrawalAmount -= initialWithDrawalAmount;

        vault.withdraw(initialWithDrawalAmount * ONE_USDC, recipient, false);

        vm.expectRevert("Withdrawal halted: impermanent loss");
        vault.withdraw(withdrawalAmount * ONE_USDC, recipient, false);
    }

    struct SeeSawConfig {
        CRV_pool pool;
        uint token1Unit;
        IERC20 token1;
        IERC20 token2;
    }

    event currentSeeSawIteration(uint iteration);
    event aboutToSeeSawTrade(uint direction);

    //The purpose of this function is to decrease IL in a CRV pair
    function seeSawTrade(uint iterations) internal {
        SeeSawConfig[] memory tradeConfig = new SeeSawConfig[](2);
        tradeConfig[0].pool = CRV_pool(constants.USDC_USDe_address());
        tradeConfig[0].token1Unit = 1e10;
        tradeConfig[0].token1 = USDC;
        tradeConfig[0].token2 = USDe;

        tradeConfig[1].pool = CRV_pool(constants.USDe_USDx_address());
        tradeConfig[1].token1Unit = 1e18;
        tradeConfig[1].token1 = USDe;
        tradeConfig[1].token2 = USDx;

        /**
         * 1. Find out current price of USDC_USDe
         * 2. Mint lots of USDC and sell into pair.
         * 3. Find out how much USDe is needed to restore price
         * 4. mint that much and assert that price is more or less restored
         */
        for (uint c = 0; c < 2; c++) {
            emit currentSeeSawIteration(c);
            SeeSawConfig memory current = tradeConfig[c];
            current.token1.approve(address(current.pool), type(uint).max);
            current.token2.approve(address(current.pool), type(uint).max);

            for (uint i = 0; i < iterations; i++) {
                uint token2Bought = current.pool.get_dy(
                    0,
                    1,
                    current.token1Unit
                );

                uint token2BalanceBefore = current.token2.balanceOf(
                    address(this)
                );
                emit aboutToSeeSawTrade(0);
                current.pool.exchange(
                    0,
                    1,
                    current.token1Unit,
                    0,
                    address(this)
                );

                uint token2BalanceAfter = current.token2.balanceOf(
                    address(this)
                );

                uint token1Reclaimed = current.pool.get_dy(1, 0, token2Bought);
                uint token1_before = current.token1.balanceOf(address(this));

                emit aboutToSeeSawTrade(1);
                current.pool.exchange(1, 0, token2Bought, 0, address(this));
                uint token1_after = current.token1.balanceOf(address(this));
            }
        }
    }

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

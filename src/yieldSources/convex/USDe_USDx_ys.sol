// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AYieldSource} from "@reflax/yieldSources/AYieldSource.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";

import {UniswapV2Router02} from "@uniswap_reflax/periphery/UniswapV2Router02.sol";
import {IWETH} from "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import {IERC20} from "@uniswap_reflax/periphery/interfaces/IERC20.sol";
import "src/Errors.sol";
import {UniswapV2Library} from "@uniswap_reflax/periphery/libraries/UniswapV2Library.sol";

//used for selling CRV rewards
struct UniswapConfig {
    UniswapV2Router02 router;
    IUniswapV2Factory factory;
    IWETH weth;
}

//index 0 is USDC and index1 is USDE. Remember USDC is 6 decimal places
abstract contract CRV_pool {
    function approve(address spender, uint256 value) public virtual returns (bool);

    //For USDC in, get_dy(1,0,1e6) returns approx 1e18
    function get_dy(int128 i, int128 j, uint256 dx) public view virtual returns (uint256);

    /**
     *
     * @param i Index value for the coin to send
     * @param j Index of receivedss
     * @param _dx amount of i
     * @param _min_dy mininum output
     * @param receiver recipient
     */
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy, address receiver) public virtual;

    function add_liquidity(uint256[] memory _amounts, uint256 _minMintAmount) public virtual returns (uint256);

    function get_balances() public view virtual returns (uint256[] memory);

    function totalSupply() public view virtual returns (uint256);

    /**
     * @notice Withdraw a single coin from the pool
     * @param _burn_amount Amount of LP tokens to burn in the withdrawal
     * @param i Index value of the coin to withdraw
     * @param _min_received Minimum amount of coin to receive
     * @param receiver Address that receives the withdrawn coins
     * @return Amount of coin received
     */
    function remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received, address receiver)
        public
        virtual
        returns (uint256);

    function calc_withdraw_one_coin(uint256 _burn_amount, int128 i) public view virtual returns (uint256);

    /**
     *
     * @notice Calculate addition or reduction in token supply from a deposit or withdrawal
     * @param _amounts Amount of each coin being deposited
     * @param is_deposit set True for deposits, False for withdrawals
     * @return Expected amount of LP tokens received
     */
    function calc_token_amount(uint256[] memory _amounts, bool is_deposit) external view virtual returns (uint256);
}

abstract contract CVX_pool {
    function withdraw(uint256 _amount, bool _claim) public virtual returns (bool);

    function withdrawAll(bool claim) public virtual;

    function getReward(address _account) public virtual;
}

abstract contract AConvexBooster {
    struct PoolInfo {
        address lptoken;
        address gauge;
        address crvRewards;
        bool shutdown;
        address factory;
    }

    //index(pid) -> pool
    PoolInfo[] public poolInfo;

    function depositAll(uint256 _pid) external virtual returns (bool);
}
//USDC-USDE CRV Pool token
//https://arbiscan.io/address/0x1c34204fcfe5314dcf53be2671c02c35db58b4e3

//recipe: swap USDC for USDe and then add USDe to USDe/USDx pool
// USDe/USDx LP token 0x096A8865367686290639bc50bF8D85C0110d9Fea
struct CRV {
    CRV_pool USDC_USDe; //USDC/USDe
    CRV_pool USDe_USDx; //USDCe/USDx
    IERC20 USDe;
}

struct Convex {
    CVX_pool pool;
    AConvexBooster booster;
    IERC20 issuedToken;
    uint256 poolId;
}

//contract USDe+USDx
//https://arbiscan.io/token/0xe062e302091f44d7483d9d6e0da9881a0817e2be#writeContract
contract USDe_USDx_ys is AYieldSource {
    UniswapConfig sushiswap; //for selling curve

    CRV crvPools;
    Convex convex;

    constructor(address usdc, address sushiswapV2Router, uint256 poolId) AYieldSource(usdc) {
        sushiswap.router = UniswapV2Router02(payable(sushiswapV2Router));
        sushiswap.factory = IUniswapV2Factory(sushiswap.router.factory());
        sushiswap.weth = IWETH(sushiswap.router.WETH());
        convex.poolId = poolId; //34 on arbitrum
    }

    function setConvex(address booster) public onlyOwner {
        convex.booster = AConvexBooster(booster);
        (address lptoken,, address rewards,,) = convex.booster.poolInfo(convex.poolId);
        convex.issuedToken = IERC20(rewards);
        convex.pool = CVX_pool(rewards);
    }

    function setCRVPools(
        address USDC_USDe, //USDC/USDe
        address convexPool, //USDCe/USDx
        address USDe
    ) public onlyOwner {
        crvPools.USDC_USDe = CRV_pool(USDC_USDe);
        crvPools.USDe_USDx = CRV_pool(convexPool);
        crvPools.USDe = IERC20(USDe);
    }

    function approvals() public {
        /*1. approve USDC token on entrance pool
          2. approve USDe on convex pool
          3. approve convex pool on booster
         */
        uint256 MAX = type(uint256).max;
        IERC20(inputToken).approve(address(crvPools.USDC_USDe), MAX);
        crvPools.USDe.approve(address(crvPools.USDe_USDx), MAX);
        crvPools.USDe.approve(address(crvPools.USDC_USDe), MAX);
        IERC20(address(crvPools.USDe_USDx)).approve(address(convex.booster), MAX);
    }

    //Hooks
    function deposit_hook(uint256 amount) internal override returns (uint256 fee, uint256 protocolUnits) {
        //USDC is index 1

        uint256 dy = crvPools.USDC_USDe.get_dy(0, 1, amount);
        require(dy > 0, "no dy");
        //SWAP USDC for USDE
        crvPools.USDC_USDe.exchange(0, 1, amount, (dy * 9996) / 10_000, address(this)); //0.04 fee
        uint256 USDe_balance = crvPools.USDe.balanceOf(address(this));
        require(USDe_balance >= dy, "USDC_USDe swap failed");

        uint256[] memory liquidity = new uint256[](2);
        liquidity[0] = USDe_balance;
        require(liquidity[0] > 0, "no USDe");
        protocolUnits = crvPools.USDe_USDx.add_liquidity(liquidity, (liquidity[0] * 990) / 1000); //0.1% fee
        fee = 14;
        uint256 balanceOfConvexPool = IERC20(address(crvPools.USDe_USDx)).balanceOf(address(this));
        require(balanceOfConvexPool > 10000, "No USDE_USDx minted");

        convex.booster.depositAll(convex.poolId);
    }

    function protocolBalance_hook() internal view override returns (uint256) {
        return convex.issuedToken.balanceOf(address(this));
    }

    function _handleClaim() internal override {
        require(address(convex.pool) != address(0), "convex pool unset");
        convex.pool.getReward(address(this));
    }

    event actualVsDesiredUSDC(uint256 actual, uint256 desired);

    function release_hook(uint256 protocolUnitsToWithdraw, uint256 desiredTokenUnitAmount)
        internal
        override
        returns (uint256 amountReleased)
    {
        uint256 USDe_dy = crvPools.USDC_USDe.get_dy(0, 1, desiredTokenUnitAmount);
        /*
            1. Get USDC_USDe pool
            2. Find out how much USDe you could get for that desired USDc amount
            3. Get USDe_USDx pool
            4. Find out how many protocol units you can mint with that much USDe.
            5. Withdraw that many protocol units.
            6. Get USDe out of USDe_USDx
            7. Use USDe to get USDc out of USDc_
            */
        uint256[] memory withdrawOfUSDeAmounts = new uint256[](2);
        withdrawOfUSDeAmounts[0] = USDe_dy;
        uint256 convexPoolUnitsNeeded = crvPools.USDe_USDx.calc_token_amount(withdrawOfUSDeAmounts, false);

        uint256 impermanentLoss = 0; //basisPoints
        if (convexPoolUnitsNeeded > protocolUnitsToWithdraw) {
            impermanentLoss = (protocolUnitsToWithdraw * 10_000) / convexPoolUnitsNeeded;
        }

        convex.pool.withdraw(protocolUnitsToWithdraw, true);

        //variable fees that max out at 0.04% for stable pools. 0.1% to withdraw
        uint256 netAmount = 10_000 - (10 + impermanentLoss);
        crvPools.USDe_USDx.remove_liquidity_one_coin(
            protocolUnitsToWithdraw, 0, (USDe_dy * netAmount) / 10_000, address(this)
        );
        uint256 usde_balance = crvPools.USDe.balanceOf(address(this));

        crvPools.USDC_USDe.exchange(1, 0, usde_balance, (desiredTokenUnitAmount * 9996) / 10_000, address(this));
        uint256 usdcBalance = IERC20(inputToken).balanceOf(address(this));

        return usdcBalance;
    }

    event get_input_value_of_protocol_deposit_hook_EVENT(uint256 convexBalancsse, uint256 usdeVal, uint256 impliedUSDC);

    function get_input_value_of_protocol_deposit_hook() internal view override returns (uint256 impliedUSDC) {
        uint256 convexBalance = convex.issuedToken.balanceOf(address(this));

        //CRV reverts on zero input
        uint256 usdeVal = convexBalance == 0 ? 0 : crvPools.USDe_USDx.calc_withdraw_one_coin(convexBalance, 0);

        impliedUSDC = usdeVal == 0 ? 0 : crvPools.USDC_USDe.get_dy(1, 0, usdeVal);
    }

    //End hooks

    function setCRV(address crv) public onlyOwner {
        address[] memory set = new address[](1);
        set[0] = crv;
        setRewardToken(set);
        IERC20(crv).approve(address(sushiswap.router), type(uint256).max);
    }

    event reserveInSell(uint256 rewardR, uint256 ethR, uint256 rewardBal);

    function sellRewardsForReferenceToken_hook(address referenceToken) internal override {
        for (uint256 i = 0; i < rewards.length; i++) {
            address rewardToken = rewards[i].tokenAddress;
            if (rewardToken == referenceToken) {
                continue;
            }
            require(rewardToken != address(0), "RewardToken not set");
            uint256 rewardBalance = IERC20(rewards[i].tokenAddress).balanceOf(address(this));
            if (rewardBalance < 100_000) {
                continue;
            }

            address ethRewardPairAddress = sushiswap.factory.getPair(rewardToken, referenceToken);
            if (ethRewardPairAddress == address(0)) {
                revert EthPairNotInitialized(rewardToken);
            }

            address[] memory path = new address[](2);
            path[0] = rewardToken;
            path[1] = referenceToken;

            (address token0,) = UniswapV2Library.sortTokens(rewardToken, referenceToken);

            (uint256 rewardReserve, uint256 refReserve,) = IUniswapV2Pair(ethRewardPairAddress).getReserves();

            if (token0 != rewardToken) {
                uint256 temp = rewardReserve;
                rewardReserve = refReserve;
                refReserve = temp;
            }

            uint256 outAmount = sushiswap.router.getAmountOut(rewardBalance, rewardReserve, refReserve);

            sushiswap.router.swapExactTokensForTokens(
                rewardBalance, outAmount, path, address(priceTilter), type(uint256).max
            );
        }
    }
}

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
struct SushiswapConfig {
    UniswapV2Router02 router;
    IUniswapV2Factory factory;
    IWETH weth;
}

//index 0 is USDC and index1 is USDE. Remember USDC is 6 decimal places
abstract contract CRV_pool {
    function approve(
        address spender,
        uint256 value
    ) public virtual returns (bool);

    //For USDC in, get_dy(1,0,1e6) returns approx 1e18
    function get_dy(
        uint128 i,
        uint128 j,
        uint dx
    ) public view virtual returns (uint);

    /**
     *
     * @param i Index value for the coin to send
     * @param j Index of receivedss
     * @param _dx amount of i
     * @param _min_dy mininum output
     * @param receiver recipient
     */
    function exchange(
        uint128 i,
        uint128 j,
        uint _dx,
        uint _min_dy,
        address receiver
    ) public virtual;

    function addLiquidity(
        uint256[] memory _amounts,
        uint256 _minMintAmount,
        address _receiver
    ) public virtual returns (uint256);

    function get_balances() public view virtual returns (uint[] memory);

    function totalSupply() public view virtual returns (uint);

    /**
     *@notice Withdraw a single coin from the pool
     *@param _burn_amount Amount of LP tokens to burn in the withdrawal
     *@param i Index value of the coin to withdraw
     *@param _min_received Minimum amount of coin to receive
     *@param receiver Address that receives the withdrawn coins
     *@return Amount of coin received
     */
    function remove_liquidity_one_coin(
        uint _burn_amount,
        int128 i,
        uint _min_received,
        address receiver
    ) public virtual returns (uint256);

    function calc_withdraw_one_coin(
        uint256 _burn_amount,
        int128 i
    ) public view virtual returns (uint256);

    /**
     *
     *@notice Calculate addition or reduction in token supply from a deposit or withdrawal
     *@param _amounts Amount of each coin being deposited
     *@param is_deposit set True for deposits, False for withdrawals
     *@return Expected amount of LP tokens received
     */
    function calc_token_amount(
        uint[] memory _amounts,
        bool is_deposit
    ) external view virtual returns (uint);
}

abstract contract CVX_pool {
    function withdraw(
        uint256 _amount,
        bool _claim
    ) public virtual returns (bool);

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

    function depositAll(
        uint256 _pid,
        uint upTo
    ) external virtual returns (bool);
}
//USDC-USDE CRV Pool token
//https://arbiscan.io/address/0x1c34204fcfe5314dcf53be2671c02c35db58b4e3

//recipe: swap USDC for USDe and then add USDe to USDe/USDx pool
// USDe/USDx LP token 0x096A8865367686290639bc50bF8D85C0110d9Fea
struct CRV {
    CRV_pool USDC_USDe; //USDC/USDe
    CRV_pool convexPool; //USDCe/USDx
    IERC20 USDe;
}

struct Convex {
    CVX_pool pool;
    AConvexBooster booster;
    IERC20 issuedToken;
    uint poolId;
}

//contract USDe+USDx
//https://arbiscan.io/token/0xe062e302091f44d7483d9d6e0da9881a0817e2be#writeContract
contract USDe_USDx_ys is AYieldSource {
    SushiswapConfig sushiswap;
    CRV crvPools;
    Convex convex;

    constructor(
        address usdc,
        address sushiswapV2Router,
        uint poolId
    ) AYieldSource(usdc) {
        sushiswap.router = UniswapV2Router02(payable(sushiswapV2Router));
        sushiswap.factory = IUniswapV2Factory(sushiswap.router.factory());
        sushiswap.weth = IWETH(sushiswap.router.WETH());
        convex.poolId = poolId; //34 on mainnet
    }

    function setConvex(address booster) public onlyOwner {
        convex.booster = AConvexBooster(booster);
        (address lptoken, , address rewards, , ) = convex.booster.poolInfo(
            convex.poolId
        );
        convex.issuedToken = IERC20(rewards);
        convex.pool = CVX_pool(rewards);
    }

    function setCRVPools(
        address USDC_USDe, //USDC/USDe
        address convexPool, //USDCe/USDx
        address USDe
    ) public onlyOwner {
        crvPools.USDC_USDe = CRV_pool(USDC_USDe);
        crvPools.convexPool = CRV_pool(convexPool);
        crvPools.USDe = IERC20(USDe);
    }

    function approvals() public {
        /*1. approve USDC token on entrance pool
          2. approve USDe on convex pool
          3. approve convex pool on booster
         */
        uint MAX = type(uint).max;
        IERC20(inputToken).approve(address(crvPools.USDC_USDe), MAX);
        crvPools.USDe.approve(address(crvPools.convexPool), MAX);

        IERC20(address(crvPools.convexPool)).approve(
            address(convex.booster),
            MAX
        );
    }

    //Hooks
    event USDE_USDX_MINTED(uint amount);

    function deposit_hook(uint amount, uint upTo) internal override {
        require(upTo > 99050, "UP TO deposit hook");
        //USDC is index 1

        uint dy = crvPools.USDC_USDe.get_dy(0, 1, amount);
        require(dy > 0, "no dy");
        //SWAP USDC for USDE
        require(upTo > 99100, "UP TO deposit hook");
        crvPools.USDC_USDe.exchange(0, 1, amount, dy, address(this));
        require(upTo > 99200, "UP TO deposit hook");
        uint USDe_balance = crvPools.USDe.balanceOf(address(this));
        require(USDe_balance >= dy, "USDC_USDe swap failed");
        require(upTo > 99300, "UP TO deposit hook");

        uint[] memory liquidity = new uint[](2);
        liquidity[0] = USDe_balance;
        require(liquidity[0] > 0, "no USDe");
        crvPools.convexPool.addLiquidity(liquidity, 0, address(this));
        uint balanceOfConvexPool = IERC20(address(crvPools.convexPool))
            .balanceOf(address(this));
        require(balanceOfConvexPool > 10000, "No USDE_USDx minted");
        emit USDE_USDX_MINTED(balanceOfConvexPool);
        require(upTo > 99305, "UP TO deposit hook");
        /*
           uint[] memory liquidity = new uint[](2);
        liquidity[0] = 100_000 * ONE_USDC;
        liquidity[1] = 100_000 * ONE;

        USDC_USDe_crv.addLiquidity(liquidity, 0, address(this));
        uint liquidityMinted = USDC_USDe_crv.balanceOf(address(this));

        vm.assertGt(liquidityMinted, 1 ether);

        liquidity[0] = 100_000 * ONE;

        USDe_USDx_crv.addLiquidity(liquidity, 0, address(this));
        */

        convex.booster.depositAll(convex.poolId, upTo);
        require(upTo > 99400, "UP TO deposit hook");
    }

    function protocolBalance_hook() internal view override returns (uint) {
        return convex.issuedToken.balanceOf(address(this));
    }

    function _handleClaim() internal override {
        require(address(convex.pool) != address(0), "convex pool unset");
        convex.pool.getReward(address(this));
    }

    event USDe_taken(uint USDe);

    function release_hook(
        uint protocolUnitsBalance,
        uint desiredTokenUnitAmount
    ) internal override {
        uint USDe_dy = crvPools.USDC_USDe.get_dy(0, 1, desiredTokenUnitAmount);
        emit USDe_taken(USDe_dy);
        /*
        1. Get USDC_USDe pool
        2. Find out how much USDe you could get for that desired USDc amount
        3. Get USDe_USDx pool
        4. Find out how many protocol units you can mint with that much USDe.
        5. Withdraw that many protocol units.
        6. Get USDe out of USDe_USDx
        7. Use USDe to get USDc out of USDc_
        */

        uint[] memory withdrawOfUSDeAmounts = new uint[](2);
        withdrawOfUSDeAmounts[0] = USDe_dy;
        uint protocolUnitsNeeded = crvPools.convexPool.calc_token_amount(
            withdrawOfUSDeAmounts,
            false
        );
        protocolUnitsNeeded = protocolUnitsBalance > protocolUnitsNeeded
            ? protocolUnitsNeeded
            : protocolUnitsBalance;
        convex.pool.withdraw(protocolUnitsNeeded, true);
        crvPools.convexPool.remove_liquidity_one_coin(
            protocolUnitsNeeded,
            0,
            USDe_dy,
            address(this)
        );
        uint USDC_dy = crvPools.USDC_USDe.get_dy(1, 0, USDe_dy);
        crvPools.USDC_USDe.exchange(1, 0, USDe_dy, USDC_dy, address(this));
    }

    event get_input_value_of_protocol_deposit_hook_EVENT(
        uint convexBalancsse,
        uint usdeVal,
        uint impliedUSDC
    );

    function get_input_value_of_protocol_deposit_hook()
        internal
        view
        override
        returns (uint impliedUSDC)
    {
        uint convexBalance = convex.issuedToken.balanceOf(address(this));

        uint usdeVal = crvPools.convexPool.calc_withdraw_one_coin(
            convexBalance,
            0
        );

        impliedUSDC = usdeVal == 0
            ? 0
            : crvPools.USDC_USDe.get_dy(1, 0, usdeVal);
    }

    //End hooks

    function setCRV(address crv) public onlyOwner {
        address[] memory set = new address[](1);
        set[0] = crv;
        setRewardToken(set);
        IERC20(crv).approve(address(sushiswap.router), type(uint).max);
    }

    event reserveInSell(uint rewardR, uint ethR, uint rewardBal);

    function sellRewardsForReferenceToken_hook(
        address referenceToken
    ) internal override {
        for (uint i = 0; i < rewards.length; i++) {
            address rewardToken = rewards[i].tokenAddress;
            if (rewardToken == referenceToken) {
                continue;
            }
            require(rewardToken != address(0), "RewardToken not set");
            uint rewardBalance = IERC20(rewards[i].tokenAddress).balanceOf(
                address(this)
            );
            if (rewardBalance < 100_000) {
                continue;
            }
            address ethRewardPairAddress = sushiswap.factory.getPair(
                rewardToken,
                referenceToken
            );
            if (ethRewardPairAddress == address(0)) {
                revert EthPairNotInitialized(rewardToken);
            }

            address[] memory path = new address[](2);
            path[0] = rewardToken;
            path[1] = referenceToken;

            (address token0, ) = UniswapV2Library.sortTokens(
                rewardToken,
                referenceToken
            );

            (uint rewardReserve, uint refReserve, ) = IUniswapV2Pair(
                ethRewardPairAddress
            ).getReserves();

            if (token0 != rewardToken) {
                uint temp = rewardReserve;
                rewardReserve = refReserve;
                refReserve = temp;
            }

            emit reserveInSell(rewardReserve, refReserve, rewardBalance);

            uint outAmount = sushiswap.router.getAmountOut(
                rewardBalance,
                rewardReserve,
                refReserve
            );

            sushiswap.router.swapExactTokensForTokens(
                rewardBalance,
                outAmount,
                path,
                address(priceTilter),
                type(uint).max
            );
        }
    }
}

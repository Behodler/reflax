// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../../baseContracts/AYieldSource.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import "@uniswap_reflax/periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap_reflax/periphery/interfaces/IWETH.sol";
import "@uniswap_reflax/periphery/libraries/UniswapV2Library.sol";

//used for selling CRV rewards
struct SushiswapConfig {
    IUniswapV2Router02 router;
    IUniswapV2Factory factory;
    IWETH weth;
}

//index 0 is USDE and index1 is USDC. Remember USDC is 6 decimal places
abstract contract CRV_pool {
    //For USDC in, get_dy(1,0,1e6) returns approx 1e18
    function get_dy(uint128 i, uint128 j, uint dx) public virtual view returns (uint);

    //remember to approve
    //use above to get_dy and then pass it into exchnage below
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

    function get_balances() public virtual view returns (uint[] memory);

    function totalSupply() public virtual view returns (uint);

    function remove_liquidity_one_coin(
    uint _burn_amount,
    int128 i ,
    uint _min_received,
    address receiver
    ) public virtual returns (uint256);

    function calc_withdraw_one_coin(
        uint256 _burn_amount,
        int128 i
    ) public virtual view returns (uint256);
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
        address token; //token issued by convex
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
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
    CRV_pool convexPool; //USDCe/USDx
    IERC20 USDe;
}

struct Convex {
    CVX_pool pool;
    AConvexBooster booster;
    IERC20 issuedToken;
    uint poolId;
}

//TODO: in test, make a mock convex and crv

//contract USDe+USDx
//https://arbiscan.io/token/0xe062e302091f44d7483d9d6e0da9881a0817e2be#writeContract
contract USDe_USDx is AYieldSource {
    SushiswapConfig sushiswap;
    CRV crvPools;
    Convex convex;

    constructor(address usdc, address sushiswapV2Router) AYieldSource(usdc) {
        sushiswap.router = IUniswapV2Router02(sushiswapV2Router);
        sushiswap.factory = IUniswapV2Factory(sushiswap.router.factory());
        sushiswap.weth = IWETH(sushiswap.router.WETH());
        convex.poolId = 34;
    }

    function setConvex(address booster) public onlyOwner {
        convex.booster = AConvexBooster(booster);
        (address lptoken, address token, , , , ) = convex.booster.poolInfo(
            convex.poolId
        );
        convex.issuedToken = IERC20(token);
        convex.pool = CVX_pool(lptoken);
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

    function deposit_hook(uint amount) internal override {
        //USDC is index 1
        uint dy = crvPools.USDC_USDe.get_dy(1, 0, amount);
        //SWAP USDC for USDE
        crvPools.USDC_USDe.exchange(1, 0, amount, dy, address(this));
        require(
            crvPools.USDe.balanceOf(address(this)) >= dy,
            "USDC_USDe swap failed"
        );

        //ADD USDe to USDe_USDx pool
        convex.booster.depositAll(convex.poolId);
    }

    function protocolBalance_hook() internal view override returns (uint) {
        return convex.issuedToken.balanceOf(address(this));
    }

    function _handleClaim() internal override {
        convex.pool.getReward(address(this));
    }

    function release_hook(uint amount) internal override {
        /*
        1. Release convex
        2. Unpair curve.
        3. Sell usdx into crv for usde
        4. Sell all usde into crv for usdc.
        5. return usdc balance
        */
        convex.pool.withdraw(amount, true);
        //remove all USDe
        crvPools.convexPool.remove_liquidity_one_coin(amount,0,0,address(this));
        uint usdeBalance = crvPools.USDe.balanceOf(address(this));

        //sell usdeForUSDC
        uint dy = crvPools.USDC_USDe.get_dy(0,1,amount);
        crvPools.USDC_USDe.exchange(0,1,usdeBalance,dy,address(this));
    }

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
        impliedUSDC = crvPools.USDC_USDe.get_dy(0, 1, usdeVal);
    }

    //End hooks

    function setCRV(address crv) public onlyOwner {
        address[] memory set = new address[](1);
        set[0] = crv;
        setRewardToken(set);
    }

    function sellRewardsForReferenceToken_hook(
        address referenceToken
    ) internal override {
        for (uint i = 0; i < rewards.length; i++) {
            address rewardToken = rewards[i].tokenAddress;
            if (rewardToken == referenceToken) {
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
            uint outAmount = sushiswap.router.getAmountOut(
                rewards[i].unsold,
                rewardReserve,
                refReserve
            );

            sushiswap.router.swapExactTokensForTokens(
                rewards[i].unsold,
                outAmount,
                path,
                address(priceTilter),
                type(uint).max
            );
        }
    }
}

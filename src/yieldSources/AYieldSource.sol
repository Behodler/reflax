// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Errors.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "@reflax/priceTilter/PriceTilter.sol";
import {UtilLibrary} from "../UtilLibrary.sol";

struct RewardToken {
    address tokenAddress;
}

//maintain a list of reward tokens
abstract contract AYieldSource is Ownable {
    event flaxValueOfPriceTilt(uint256 tilt, uint256 reward);
    event ReleaseInputValues(uint256 assetBalanceAfter, uint256 amount);

    uint256 constant ONE = 1 ether;
    bool open;
    //Note that inputToken is the user facing input token like eth etc.
    address inputToken;
    mapping(address => bool) approvedVaults;
    //This is the balance from calling claim on underlying protocol: token => amount
    RewardToken[] public rewards;
    PriceTilter priceTilter;
    uint256 totalDeposits;

    constructor(address _inputToken) Ownable(msg.sender) {
        inputToken = _inputToken;
    }

    /**
     * @notice big config functions can be time consuming when one wants to change one var.
     * @param _open 0 for false, 1 for true, 2 for leave as is
     * @param _inputToken zero address for leave as is
     * @param _priceTilter zero address for leave as is
     * @param _protocolName empty string for leave as is
     */
    function configure(
        uint256 _open,
        string calldata _inputToken,
        string calldata _priceTilter,
        string calldata _protocolName,
        string calldata vaultToDrop,
        string calldata vaultToApprove
    ) public onlyOwner {
        if (_open < 2) open = _open == 0 ? false : true;
        if (!UtilLibrary.isEmptyString(_protocolName)) {
            underlyingProtocolName = _protocolName;
        }

        if (!UtilLibrary.isEmptyString(_inputToken)) {
            inputToken = UtilLibrary.stringToAddress(_inputToken);
        }

        if (!UtilLibrary.isEmptyString(_priceTilter)) {
            priceTilter = PriceTilter(UtilLibrary.stringToAddress(_priceTilter));
        }
        if (!UtilLibrary.isEmptyString(vaultToDrop)) {
            approvedVaults[UtilLibrary.stringToAddress(vaultToDrop)] = false;
        }

        if (!UtilLibrary.isEmptyString(vaultToApprove)) {
            approvedVaults[UtilLibrary.stringToAddress(vaultToApprove)] = true;
        }
    }

    function setRewardToken(address[] memory rewardTokens) internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewards.push(RewardToken({tokenAddress: rewardTokens[i]}));
        }
    }

    modifier approvedVault() {
        require(approvedVaults[msg.sender], "Vault not public");
        _;
    }

    string public underlyingProtocolName; //eg. Convex

    //hooks for interacting with underlying protocol.
    ///@return fee percentage expressed as basis point
    function deposit_hook(uint256 amount) internal virtual returns (uint256 fee, uint256 protocolUnits);

    function protocolBalance_hook() internal view virtual returns (uint256);

    //from convex all the way to usdc
    function release_hook(uint256 amount, uint256 desiredAmountToRelease) internal virtual returns (uint256 fee);

    function get_input_value_of_protocol_deposit_hook() internal view virtual returns (uint256);

    function sellRewardsForReferenceToken_hook(address referenceToken) internal virtual;

    //increment unclaimedREwards
    function _handleClaim() internal virtual;

    //end hooks

    function deposit(uint256 amount, address staker)
        public
        approvedVault
        returns (uint256 depositFee, uint256 protocolUnits)
    {
        if (!open) {
            revert FundClosed();
        }
        IERC20(inputToken).transferFrom(staker, address(this), amount);
        totalDeposits += amount;
        return deposit_hook(amount);
    }

    function advanceYield() public returns (uint256 currentDepositBalance) {
        /*
        1. Claim yield on underlying asset. 
        2. Inspect priceTilter for referenceToken
        3. Sell rewards for referenceToken
        4. Give reference balance to tilter.
        5. Tilter returns flax value of tilt.
        6. Return this to caller 
        */
        _handleClaim();
        address referenceToken = priceTilter.referenceToken();
        sellRewardsForReferenceToken_hook(referenceToken);
        (uint256 flax_value_of_tilt, uint256 flax_value_of_reward_claim) = priceTilter.tilt();
        emit flaxValueOfPriceTilt(flax_value_of_tilt, flax_value_of_reward_claim);
        return (get_input_value_of_protocol_deposit_hook());
    }

    ///@return fee negative is impermanent gain, expressed as basis points
    function releaseInput(address recipient, uint256 amount, uint256 protocolUnitsToWithdraw, bool allowImpermanentLoss)
        public
        approvedVault
        returns (int256 fee)
    {
        release_hook(protocolUnitsToWithdraw, amount);
        uint256 assetBalanceAfter = IERC20(inputToken).balanceOf(address(this));

        require(allowImpermanentLoss || assetBalanceAfter >= amount, "Withdrawal halted: impermanent loss");

        fee = ((int256(amount) - int256(assetBalanceAfter)) * 10_000) / int256(amount);

        IERC20(inputToken).transfer(recipient, assetBalanceAfter);
        totalDeposits -= amount;
    }
}

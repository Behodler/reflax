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
    uint constant ONE = 1 ether;
    bool open;
    //Note that inputToken is the user facing input token like eth etc.
    address inputToken;
    mapping(address => bool) approvedVaults;
    //This is the balance from calling claim on underlying protocol: token => amount
    RewardToken[] public rewards;
    PriceTilter priceTilter;
    uint totalDeposits;

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
        uint _open,
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
            priceTilter = PriceTilter(
                UtilLibrary.stringToAddress(_priceTilter)
            );
        }
        if (!UtilLibrary.isEmptyString(vaultToDrop)) {
            approvedVaults[UtilLibrary.stringToAddress(vaultToDrop)] = false;
        }

        if (!UtilLibrary.isEmptyString(vaultToApprove)) {
            approvedVaults[UtilLibrary.stringToAddress(vaultToApprove)] = true;
        }
    }

    function setRewardToken(address[] memory rewardTokens) internal {
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewards.push(RewardToken({tokenAddress: rewardTokens[i]}));
        }
    }

    modifier approvedVault() {
        require(approvedVaults[msg.sender], "Vault not public");
        _;
    }

    string public underlyingProtocolName; //eg. Convex

    //hooks for interacting with underlying protocol.
    function deposit_hook(uint amount, uint upTo) internal virtual;

    function protocolBalance_hook() internal view virtual returns (uint);

    //from convex all the way to usdc
    function release_hook(
        uint amount,
        uint desiredAmountToRelease
    ) internal virtual;

    function get_input_value_of_protocol_deposit_hook()
        internal
        view
        virtual
        returns (uint);

    function sellRewardsForReferenceToken_hook(
        address referenceToken
    ) internal virtual;

    //increment unclaimedREwards
    function _handleClaim() internal virtual;

    //end hooks

    event fundOpen ();
    event transferSuccessful ();
    function deposit(
        uint amount,
        address staker,
        uint upTo
    ) public approvedVault {
        if (!open) {
            revert FundClosed();
        }
        emit fundOpen();
        require(upTo > 99001, "Up To Reached");
        IERC20(inputToken).transferFrom(staker, address(this), amount);
        emit transferSuccessful();
        require(upTo > 99002, "Up To Reached");
        totalDeposits += amount;
        deposit_hook(amount, upTo);
        require(upTo > 99401, "Up To Reached");
    }

    function advanceYield()
        public
        returns (uint flaxValueOfTilt, uint currentDepositBalance)
    {
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
        flaxValueOfTilt = priceTilter.tilt();
        return (flaxValueOfTilt, get_input_value_of_protocol_deposit_hook());
    }

    function releaseInput(
        address recipient,
        uint amount,
        bool allowImpermanentLoss
    ) public approvedVault {
        uint protolUnitsToWithdraw = protocolBalance_hook();

        uint assetBalanceBefore = IERC20(inputToken).balanceOf(address(this));
        release_hook(protolUnitsToWithdraw, amount);
        uint assetBalanceAfter = IERC20(inputToken).balanceOf(address(this));

        require(
            allowImpermanentLoss ||
                assetBalanceAfter - assetBalanceBefore > amount,
            "Withdrawal halted: impermanent loss"
        );
        IERC20(inputToken).transfer(recipient, amount);
        totalDeposits -= amount;
    }
}

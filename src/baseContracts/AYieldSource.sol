// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "../Errors.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";
import {PriceTilter} from "../PriceTilter.sol";
import "../UtilLibrary.sol";
struct RewardToken {
    address tokenAddress;
    uint unsold;
}

//maintain a list of reward tokens
abstract contract AYieldSource is Ownable {
    uint constant ONE = 1 ether;
    bool open;
    //Note that inputToken is the user facing input token like eth etc.
    address inputToken;
    mapping(address => bool) approvedBrokers;
    //This is the balance from calling claim on underlying protocol: token => amount
    RewardToken[] public rewards;
    PriceTilter priceTilter;
    uint totalDeposits;

    function redeemRate() public view returns (uint) {
        return (protocolBalance_hook() * ONE) / totalDeposits;
    }

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
        string calldata brokerToDrop,
        string calldata brokerToApprove
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
        if (!UtilLibrary.isEmptyString(brokerToDrop)) {
            approvedBrokers[UtilLibrary.stringToAddress(brokerToDrop)] = false;
        }

        if (!UtilLibrary.isEmptyString(brokerToApprove)) {
            approvedBrokers[
                UtilLibrary.stringToAddress(brokerToApprove)
            ] = true;
        }
    }

    function setRewardToken(address[] memory rewardTokens) internal {
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewards.push(
                RewardToken({tokenAddress: rewardTokens[i], unsold: 0})
            );
        }
    }

    modifier approvedBroker() {
        require(approvedBrokers[msg.sender], "Vault not public");
        _;
    }

    string public underlyingProtocolName; //eg. Convex

    //hooks for interacting with underlying protocol.
    function deposit_hook(uint amount) internal virtual;

    function protocolBalance_hook() internal view virtual returns (uint);

    //from convex all the way to usdc
    function release_hook(uint amount) internal virtual;

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

    function deposit(uint amount) public approvedBroker {
        if (!open) {
            revert FundClosed();
        }
        IERC20(inputToken).transferFrom(msg.sender, address(this), amount);
        totalDeposits += amount;
        deposit_hook(amount);
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
    ) public approvedBroker {
        uint _redeemRate = redeemRate();
        uint protolUnitsToWithdraw = (amount * _redeemRate) / ONE;
        release_hook(protolUnitsToWithdraw);
        uint assetBalanceBefore = IERC20(inputToken).balanceOf(address(this));
        IERC20(inputToken).transfer(address(this), amount);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";

interface IsFlax is IERC20 {
    function burn(uint amount) external;
}

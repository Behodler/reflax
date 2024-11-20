// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import {IERC20, ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";

contract Flax is ERC20 {


    constructor(string memory name) ERC20(name, name) {
        
    }


    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}

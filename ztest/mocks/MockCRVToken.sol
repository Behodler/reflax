// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import { ERC20} from "@oz_reflax/contracts/token/ERC20/ERC20.sol";

contract MockCRVToken is ERC20 {
    constructor() ERC20("Curve", "crv") {}

    function mint(address recipient, uint amount) public {
        _mint(recipient, amount);
    }
}
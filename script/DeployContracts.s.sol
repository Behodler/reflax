// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract DeployContracts is Script {
    function run() public {

        /*
        1. Deploy Flax
        2. Deploy SFlax and Locker
        3. Mint a bunch of Flax and lock
        4. Intantiate major tokens
        5. Instantiate pools
        6. Steal whale's USDC
        7. Approve pools on major tokens (maybe leave out)
        8. deploy vault
        9. Instantiate UniswapMaker with sushi address (remember to use Uni address in price tilter)
        10. deploy yieldSource
        11. yieldSource.setConvex
        12. oracle
        */
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library UtilLibrary {
    function isEmptyString(string memory value) external pure returns (bool){
        return bytes(value).length==0;
    }

    function stringToAddress(string memory str) external pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "Invalid address length"); // 42 includes "0x" and 40 hex characters
        require(
            strBytes[0] == "0" && strBytes[1] == "x",
            "Address should start with 0x"
        );

        uint160 addr = 0;
        for (uint i = 2; i < 42; i++) {
            uint160 b = uint160(uint8(strBytes[i]));

            if (b >= 48 && b <= 57) {
                b -= 48; // '0' - '9'
            } else if (b >= 65 && b <= 70) {
                b -= 55; // 'A' - 'F'
            } else if (b >= 97 && b <= 102) {
                b -= 87; // 'a' - 'f'
            } else {
                revert("Invalid character in address");
            }

            addr = addr * 16 + b;
        }

        return address(addr);
    }
}

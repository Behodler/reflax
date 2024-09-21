// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Vm} from "forge-std/Test.sol";
library UtilLibrary {
    function isEmptyString(string memory value) external pure returns (bool) {
        return bytes(value).length == 0;
    }

    function stringToAddress(
        string memory str
    ) external pure returns (address) {
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

    function toAsciiString(address x) external pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(abi.encodePacked("0x", string(s)));
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

}

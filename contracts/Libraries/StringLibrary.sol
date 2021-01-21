// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

library StringLibrary {
  function append(string memory a, string memory b) internal pure returns (string memory) {
    return string(abi.encodePacked(a, b));
  }
}

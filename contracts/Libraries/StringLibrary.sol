// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/// @title String Library
/// @author Affax
/// @dev A library to manipulate strings
library StringLibrary {
  /// @dev Append two string together
  /// @param a First string
  /// @param b Second string
  /// @return Result of appending two input strings
  function append(string memory a, string memory b) internal pure returns (string memory) {
    return string(abi.encodePacked(bytes(a), bytes(b)));
  }
}

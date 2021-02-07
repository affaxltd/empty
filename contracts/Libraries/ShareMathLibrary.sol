// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

/// @title Share Math Library
/// @author Affax
/// @dev A library to calculate share math with
library ShareMathLibrary {
  using SafeMath for uint256;

  /// @dev Calculate amount of underlying tokens from shares
  /// @param shares Amount of vault shares
  /// @param totalShares Total shares for vault
  /// @param balance Total amount of underlying tokens
  /// @return Calculated amount of underlying tokens
  function calculateAmount(
    uint256 shares,
    uint256 totalShares,
    uint256 balance
  ) internal pure returns (uint256) {
    return shares.mul(balance).div(totalShares);
  }

  /// @dev Calculate shares from amount of underlying tokens
  /// @param amount Amount of underlying tokens
  /// @param totalShares Total shares for vault
  /// @param balance Total amount of underlying tokens
  /// @return Calculated shares
  function calculateShares(
    uint256 amount,
    uint256 totalShares,
    uint256 balance
  ) internal pure returns (uint256) {
    return amount.mul(totalShares).div(balance);
  }
}

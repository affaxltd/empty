// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

library ShareMathLibrary {
  using SafeMath for uint256;

  function calculateAmount(
    uint256 shares,
    uint256 totalShares,
    uint256 balance
  ) internal pure returns (uint256) {
    return shares.mul(balance).div(totalShares);
  }

  function calculateShares(
    uint256 amount,
    uint256 totalShares,
    uint256 balance
  ) internal pure returns (uint256) {
    return amount.mul(totalShares).div(balance);
  }
}

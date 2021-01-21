// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface ICurveSwap {
  function get_dy(
    int128 i,
    int128 j,
    uint256 dx
  ) external view returns (uint256);

  function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external;

  function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external;

  function remove_liquidity(uint256 amount, uint256[] memory min_amounts) external;
}

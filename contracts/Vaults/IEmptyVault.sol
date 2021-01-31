// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IEmptyVault {
  /*
   * STATE CHANGING FUNCTIONS
   */

  function deposit(uint256 amount, address to) external returns (uint256 userShare);

  function withdraw(
    address from,
    uint256 stake,
    address to
  ) external returns (uint256 amount, uint256 eth);

  function claimETH(
    address from,
    address to,
    uint256 shares,
    uint256 totalShares
  ) external returns (uint256 claimedEth);

  /*
   * STATE READING FUNCTIONS
   */

  function tvl() external view returns (uint256);

  function balanceOf(address who) external view returns (uint256);

  function totalShares() external view returns (uint256);

  function earnedETH(address who) external view returns (uint256);

  function underlyingBalanceOf(address who) external view returns (uint256);

  function underlying() external view returns (address);

  function pool() external view returns (address);

  function vault() external view returns (address);

  function name() external view returns (string memory);
}

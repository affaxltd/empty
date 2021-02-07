// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/// @title Vault Interface
/// @author Affax
/// @dev Contains all required functions for vault logic
interface IEmptyVault {
  /*
   * STATE CHANGING FUNCTIONS
   */

  /// @dev Deposits & stakes user's asset into Harvest and gives them a share of the total pool
  /// @param amount Amount of tokens to stake
  /// @param to Address to give shares to
  /// @return shares amount of shares gotten
  /// @return eth Amount of ETH bonuses claimed from withdraw
  function deposit(uint256 amount, address to) external returns (uint256 shares, uint256 eth);

  /// @dev Unstakes & withdraws tokens from Harvest
  /// @param from Address that withdraws shares
  /// @param shares Amount of shares to withdraw
  /// @param to Address to give tokens to
  /// @return amount Amount of tokens withdrawed from Harvest vault
  /// @return eth Amount of ETH bonuses claimed from withdraw
  function withdraw(
    address from,
    uint256 shares,
    address to
  ) external returns (uint256 amount, uint256 eth);

  /// @dev Claims ETH for address
  /// @param from Address to claim WETH on
  /// @param to Address to receive WETH
  /// @param shares Shares of address used in debt formula
  /// @param total Total shares used in debt formula
  /// @return eth Amount of ETH claimed
  function claimETH(
    address from,
    address to,
    uint256 shares,
    uint256 total
  ) external returns (uint256 eth);

  /*
   * STATE READING FUNCTIONS
   */

  /// @return Total value locked in underlying tokens
  function tvl() external view returns (uint256);

  /// @param who Address to query data on
  /// @return Balance of address in shares
  function balanceOf(address who) external view returns (uint256);

  /// @return Total amount of shares
  function totalShares() external view returns (uint256);

  /// @param who Address to query data on
  /// @return Earned WETH for address
  function earnedETH(address who) external view returns (uint256);

  /// @param who Address to query data on
  /// @return Balance of address in underlying tokens
  function underlyingBalanceOf(address who) external view returns (uint256);

  /// @return Address of underlying token
  function underlying() external view returns (address);

  /// @return Address of underlying pool
  function pool() external view returns (address);

  /// @return Address of underlying vault
  function vault() external view returns (address);

  /// @return Name of vault
  function name() external view returns (string memory);
}

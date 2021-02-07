// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IHarvestPool {
  function stake(uint256 amount) external;

  function withdraw(uint256 amount) external;

  function exit() external;

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function earned(address account) external view returns (uint256);

  function lpToken() external view returns (address);

  function getReward() external;
}

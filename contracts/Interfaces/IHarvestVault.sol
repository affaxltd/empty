// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHarvestVault is IERC20 {
  function underlyingBalanceInVault() external view returns (uint256);

  function underlyingBalanceWithInvestment() external view returns (uint256);

  function underlying() external view returns (address);

  function deposit(uint256 amountWei) external;

  function depositFor(uint256 amountWei, address holder) external;

  function withdraw(uint256 numberOfShares) external;

  function getPricePerFullShare() external view returns (uint256);

  function underlyingBalanceWithInvestmentForHolder(address holder) external view returns (uint256);
}

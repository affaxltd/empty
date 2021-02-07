// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";

/// @title Vault Data Contract
/// @author Affax
/// @dev A contract to specify solidity's storage mapping for vault contracts
contract EmptyVaultData {
  /*
   * INTERNAL VARIABLES
   */

  EmptySingularity internal _singularity;
  IHarvestVault internal _vault;
  IHarvestPool internal _pool;
  IERC20 internal _underlying;
  string internal _name;

  mapping(address => uint256) internal _balance;
  mapping(address => uint256) internal _debt;
  uint256 internal _totalETH;
  uint256 internal _totalShares;
}

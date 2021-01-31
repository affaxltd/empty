// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";

contract EmptyVaultData {
  /*
   * CONSTANTS
   */

  address internal constant FarmEthPair = 0x56feAccb7f750B997B36A68625C7C596F0B41A58;
  address internal constant FarmAddress = 0xa0246c9032bC3A600820415aE600c6388619A14D;
  address internal constant WethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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

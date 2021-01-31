// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {StringLibrary} from "../Libraries/StringLibrary.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";
import {EmptyVaultData} from "../Vaults/EmptyVaultData.sol";
import {EmptyProxy} from "./EmptyProxy.sol";

contract EmptyVaultProxy is EmptyProxy, EmptyVaultData {
  function implementation() public view override returns (address) {
    return _singularity.vaultTarget();
  }

  constructor(address _singularityAddress, address _poolAddress) public {
    _singularity = EmptySingularity(_singularityAddress);
    _pool = IHarvestPool(_poolAddress);
    _vault = IHarvestVault(_pool.lpToken());
    _underlying = IERC20(_vault.underlying());
    _name = StringLibrary.append("Empty.fi ", ERC20(address(_underlying)).name());
  }
}

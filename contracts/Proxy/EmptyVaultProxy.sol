// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {StringLibrary} from "../Libraries/StringLibrary.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";
import {EmptyVaultData} from "../Vaults/EmptyVaultData.sol";
import {EmptyProxy} from "./EmptyProxy.sol";

/// @title Vault Proxy Contract
/// @author Affax
/// @dev Implementation of the EmptyProxy proxy for Emptyfi vaults
contract EmptyVaultProxy is EmptyProxy, EmptyVaultData {
  /// @dev Tells the address of the implementation where every call will be delegated.
  /// @return address of the implementation to which it will be delegated
  function implementation() public view override returns (address) {
    return _singularity.vaultTarget();
  }

  /// @dev Constructor setting up vault proxy contract
  /// @param _singularityAddress Singularity contract address
  /// @param _poolAddress Pool contract address
  constructor(address _singularityAddress, address _poolAddress) {
    _singularity = EmptySingularity(_singularityAddress);
    _pool = IHarvestPool(_poolAddress);
    _vault = IHarvestVault(_pool.lpToken());
    _underlying = IERC20(_vault.underlying());

    // Setting name based on Emptyfi appended to underlying asset name
    _name = StringLibrary.append("Emptyfi ", ERC20(address(_underlying)).name());
  }
}

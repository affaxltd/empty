// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/// @title Proxy Contract
/// @author Affax
/// @dev Allows for functionality to be loaded from another contract while running in local storage space
abstract contract EmptyProxy {
  /// @dev Tells the address of the implementation where every call will be delegated.
  /// @return address of the implementation to which it will be delegated
  function implementation() public view virtual returns (address);

  /// @dev ERC897
  /// @return whether it is a forwarding (1) or an upgradeable (2) proxy
  function proxyType() public pure returns (uint256) {
    return 2;
  }

  /// @dev Function to receive ETH
  receive() external payable {}

  /// @dev Explain to a developer any extra details
  /// returns This function will return whatever the implementation call returns
  fallback() external payable {
    address _impl = implementation();

    require(_impl != address(0), "Implementation not set");

    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
        // delegatecall returns 0 on error.
        case 0 {
          revert(0, returndatasize())
        }
        default {
          return(0, returndatasize())
        }
    }
  }
}

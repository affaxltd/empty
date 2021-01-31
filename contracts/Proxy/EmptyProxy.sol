// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

abstract contract EmptyProxy {
  /**
   * @dev Tells the address of the implementation where every call will be delegated.
   * @return address of the implementation to which it will be delegated
   */
  function implementation() public view virtual returns (address);

  /**
   * @dev ERC897
   * @return whether it is a forwarding (1) or an upgradeable (2) proxy
   */
  function proxyType() public pure returns (uint256) {
    return 2;
  }

  receive() external payable {}

  /**
   * @dev Fallback function allowing to perform a delegatecall to the given implementation.
   * This function will return whatever the implementation call returns
   */
  fallback() external payable {
    address _impl = implementation();

    require(_impl != address(0), "Implementation not set");

    assembly {
      calldatacopy(0, 0, calldatasize())
      let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
        case 0 {
          revert(0, returndatasize())
        }
        default {
          return(0, returndatasize())
        }
    }
  }
}

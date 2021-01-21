// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {Context} from "@openzeppelin/contracts/GSN/Context.sol";

/**
 * @dev A controllable contract binding to the creator
 */
contract Controllable is Context {
  address internal _controller;
  bool internal _set;

  modifier onlyController() {
    // Check that the calling address is the controller
    require(_msgSender() == _controller, "Not the controller");
    _;
  }

  constructor() public {
    _controller = _msgSender();
  }

  function destroyController() public onlyController {
    _controller = address(0);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {StringLibrary} from "../Libraries/StringLibrary.sol";

contract EmptyStake is ERC20 {
  ERC20 internal _underlying;

  constructor(ERC20 underlying)
    public
    ERC20(StringLibrary.append("empty", underlying.name()), StringLibrary.append("e", underlying.symbol()))
  {
    _underlying = underlying;
  }
}

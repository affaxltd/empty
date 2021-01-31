// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {TimelockController} from "@openzeppelin/contracts/access/TimelockController.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Context} from "@openzeppelin/contracts/GSN/Context.sol";

import {IUniswapV2Pair} from "../Interfaces/Uniswap/IUniswapV2Pair.sol";
import {ShareMathLibrary} from "../Libraries/ShareMathLibrary.sol";
import {UniswapV2Library} from "../Libraries/UniswapV2Library.sol";
import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {StringLibrary} from "../Libraries/StringLibrary.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";
import {IWETH} from "../Interfaces/Tokens/IWETH.sol";
import {EmptyVaultData} from "./EmptyVaultData.sol";
import {IEmptyVault} from "./IEmptyVault.sol";

contract EmptyVaultV1 is IEmptyVault, EmptyVaultData, Context {
  using ShareMathLibrary for uint256;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /**
   * @dev Fee info, 10% of earned ETH is paid to dev
   */
  uint256 public constant MAX_FEE = 100;
  uint256 public constant FEE = 10;

  receive() external payable {}

  /*
   * Modifiers
   */

  modifier _onlyAuthorizedAccess() {
    require(_msgSender() == address(_singularity) || _msgSender() == address(this), "Not authorized");
    _;
  }

  /*
   * PUBLIC STATE CHANGING FUNCTIONS
   */

  function deposit(uint256 amount, address to) external override _onlyAuthorizedAccess returns (uint256 userShare) {
    _underlying.safeIncreaseAllowance(address(_vault), amount);
    _vault.deposit(amount);

    uint256 undepositedShares = _vault.balanceOf(address(this));

    IERC20(_vault).safeIncreaseAllowance(address(_pool), undepositedShares);
    _pool.stake(undepositedShares);

    userShare = _totalShares == 0 ? amount : amount.calculateShares(_totalShares, tvl());

    uint256 newShare = _balance[to].sub(userShare);
    uint256 newTotal = _totalShares.sub(userShare);

    claimETH(to, to, newShare, newTotal);

    _balance[to] = newShare;
    _totalShares = newTotal;
  }

  function withdraw(
    address from,
    uint256 stake,
    address to
  ) external override _onlyAuthorizedAccess returns (uint256 amount, uint256 eth) {
    uint256 amountInShares = stake.calculateShares(_pool.balanceOf(address(this)), _totalShares);
    uint256 initialAmount = _underlying.balanceOf(address(this));

    uint256 newShare = _balance[from].sub(stake);
    uint256 newTotal = _totalShares.sub(stake);

    eth = claimETH(from, to, newShare, newTotal);

    _pool.withdraw(amountInShares);
    _vault.withdraw(amountInShares);

    amount = _underlying.balanceOf(address(this)).sub(initialAmount);
    _underlying.safeTransfer(to, amount);

    _balance[from] = newShare;
    _totalShares = newTotal;
  }

  function claimETH(
    address from,
    address to,
    uint256 shares,
    uint256 totalShares
  ) public override _onlyAuthorizedAccess returns (uint256 claimedEth) {
    _performHarvest();

    claimedEth = _calculateETH(_balance[from], _totalShares, _totalETH, _debt[from]);
    uint256 debt = _debt[from];

    if (claimedEth > 0) {
      _totalETH = _totalETH.sub(claimedEth).sub(debt);
      IERC20(WethAddress).safeTransfer(to, claimedEth);
    }

    if (shares > 0) {
      _calculateETHAndDebt(from, shares, totalShares);
    }
  }

  /*
   * PUBLIC STATE READING FUNCTIONS
   */

  function tvl() public view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    return
      _pool.balanceOf(address(this)).calculateAmount(_vault.totalSupply(), _vault.underlyingBalanceWithInvestment());
  }

  function balanceOf(address who) external view override returns (uint256) {
    return _balance[who];
  }

  function totalShares() external view override returns (uint256) {
    return _totalShares;
  }

  function earnedETH(address who) external view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    if (_balance[who] == 0) {
      return 0;
    }

    return _calculateETH(_balance[who], _totalShares, _totalETH + _earnedETH(), _debt[who]);
  }

  function underlyingBalanceOf(address who) external view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    if (_balance[who] == 0) {
      return 0;
    }

    return _balance[who].calculateAmount(_totalShares, tvl());
  }

  function underlying() external view override returns (address) {
    return address(_underlying);
  }

  function pool() external view override returns (address) {
    return address(_pool);
  }

  function vault() external view override returns (address) {
    return address(_vault);
  }

  function name() external view override returns (string memory) {
    return _name;
  }

  /*
   * PRIVATE STATE CHANGING FUNCTIONS
   */

  function _performHarvest() internal {
    uint256 earnedAmount = _pool.earned(address(this));
    if (earnedAmount == 0) return;

    uint256 ethOut = _tokensOut(FarmEthPair, earnedAmount);
    if (ethOut == 0) return;

    IERC20(FarmAddress).safeTransfer(FarmEthPair, earnedAmount);
    IUniswapV2Pair(FarmEthPair).swap(ethOut, 0, address(this), new bytes(0));

    uint256 calculatedFee = ethOut.mul(FEE).div(MAX_FEE);
    uint256 remainingWeth = ethOut.sub(calculatedFee);

    if (calculatedFee > 0) {
      IERC20(WethAddress).safeTransfer(_singularity.dev(), calculatedFee);
    }

    _totalETH = _totalETH.add(remainingWeth);
  }

  function _calculateETHAndDebt(
    address who,
    uint256 shares,
    uint256 total
  ) internal {
    if (shares == 0) return;

    uint256 debt = _totalETH == 0 ? 0 : _calculateDebt(_totalETH, shares, total);

    if (debt == 0) return;

    _debt[who] = _debt[who].add(debt);
    _totalETH = _totalETH.add(debt);
  }

  /**
   * PRIVATE STATE READING FUNCTIONS
   */

  function _earnedETH() internal view returns (uint256) {
    uint256 earnedAmount = _pool.earned(address(this));

    if (earnedAmount == 0) {
      return 0;
    }

    uint256 ethOut = _tokensOut(FarmEthPair, earnedAmount);
    uint256 calculatedFee = ethOut.mul(FEE).div(MAX_FEE);
    uint256 remainingWeth = ethOut.sub(calculatedFee);

    return remainingWeth;
  }

  function _tokensOut(address pairAddress, uint256 amount) internal view returns (uint256) {
    (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress).getReserves();
    return UniswapV2Library.getAmountOut(amount, reserve0, reserve1);
  }

  /*
   * PRIVATE PURE FUNCTIONS
   */

  function _calculateDebt(
    uint256 eth,
    uint256 stake,
    uint256 totalStake
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth).mul(2), totalStake);
  }

  function _calculateETH(
    uint256 stake,
    uint256 totalStake,
    uint256 eth,
    uint256 ethDebt
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth), totalStake).sub(ethDebt);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {TimelockController} from "@openzeppelin/contracts/access/TimelockController.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Context} from "@openzeppelin/contracts/GSN/Context.sol";

import {IUniswapV2Router02} from "../Interfaces/Uniswap/IUniswapV2Router02.sol";
import {ShareMathLibrary} from "../Libraries/ShareMathLibrary.sol";
import {UniswapV2Library} from "../Libraries/UniswapV2Library.sol";
import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {EmptySingularity} from "../Core/EmptySingularity.sol";
import {StringLibrary} from "../Libraries/StringLibrary.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";
import {IWETH} from "../Interfaces/Tokens/IWETH.sol";
import {EmptyVaultData} from "./EmptyVaultData.sol";
import {IEmptyVault} from "./IEmptyVault.sol";

/// @title Harvest Vault V1 Contract
/// @author Affax
/// @dev V1 vault contract for Harvest's vaults
contract EmptyVaultV1 is IEmptyVault, EmptyVaultData, Context {
  using ShareMathLibrary for uint256;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /*
   * CONSTANTS
   */

  address internal constant RouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address internal constant FarmAddress = 0xa0246c9032bC3A600820415aE600c6388619A14D;
  address internal constant WethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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

  /// Deposits & stakes user's asset into Harvest and gives them a share of the total pool
  /// @inheritdoc IEmptyVault
  function deposit(uint256 amount, address to)
    external
    override
    _onlyAuthorizedAccess
    returns (uint256 shares, uint256 eth)
  {
    shares = _totalShares == 0 ? amount : amount.calculateShares(_totalShares, tvl());
    uint256 newShare = _balance[to].add(shares);
    uint256 newTotal = _totalShares.add(shares);

    eth = claimETH(to, to, newShare, newTotal);

    _balance[to] = newShare;
    _totalShares = newTotal;

    _underlying.safeIncreaseAllowance(address(_vault), amount);
    _vault.deposit(amount);

    uint256 undepositedShares = _vault.balanceOf(address(this));
    IERC20(_vault).safeIncreaseAllowance(address(_pool), undepositedShares);
    _pool.stake(undepositedShares);
  }

  /// Withdraws staked & deposited tokens from Harvest
  /// @inheritdoc IEmptyVault
  function withdraw(
    address from,
    uint256 shares,
    address to
  ) external override _onlyAuthorizedAccess returns (uint256 amount, uint256 eth) {
    uint256 amountInShares = shares.calculateShares(_pool.balanceOf(address(this)), _totalShares);
    uint256 initialAmount = _underlying.balanceOf(address(this));
    uint256 newShare = _balance[from].sub(shares);
    uint256 newTotal = _totalShares.sub(shares);

    eth = claimETH(from, to, newShare, newTotal);

    _balance[from] = newShare;
    _totalShares = newTotal;

    _pool.withdraw(amountInShares);
    _vault.withdraw(amountInShares);

    amount = _underlying.balanceOf(address(this)).sub(initialAmount);
    _underlying.safeTransfer(to, amount);
  }

  /// Tells the address of the implementation where every call will be delegated
  /// @inheritdoc IEmptyVault
  function claimETH(
    address from,
    address to,
    uint256 shares,
    uint256 total
  ) public override _onlyAuthorizedAccess returns (uint256 eth) {
    _performHarvest();

    if (_totalETH > 0) {
      eth = _calculateETH(_balance[from], _totalShares, _totalETH, _debt[from]);
      uint256 debt = _debt[from];

      if (eth > 0) {
        _totalETH = _totalETH.sub(eth).sub(debt);
        IERC20(WethAddress).transfer(to, eth);
      }
    } else {
      eth = 0;
    }

    if (shares > 0) {
      _calculateETHAndDebt(from, shares, total);
    }
  }

  /*
   * PUBLIC STATE READING FUNCTIONS
   */

  /// @inheritdoc IEmptyVault
  function tvl() public view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    return
      _pool.balanceOf(address(this)).calculateAmount(_vault.totalSupply(), _vault.underlyingBalanceWithInvestment());
  }

  /// @inheritdoc IEmptyVault
  function balanceOf(address who) external view override returns (uint256) {
    return _balance[who];
  }

  /// @inheritdoc IEmptyVault
  function totalShares() external view override returns (uint256) {
    return _totalShares;
  }

  /// @inheritdoc IEmptyVault
  function earnedETH(address who) external view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    if (_balance[who] == 0) {
      return 0;
    }

    return _calculateETH(_balance[who], _totalShares, _totalETH + _earnedETH(), _debt[who]);
  }

  /// @inheritdoc IEmptyVault
  function underlyingBalanceOf(address who) external view override returns (uint256) {
    if (_totalShares == 0) {
      return 0;
    }

    if (_balance[who] == 0) {
      return 0;
    }

    return _balance[who].calculateAmount(_totalShares, tvl());
  }

  /// @inheritdoc IEmptyVault
  function underlying() external view override returns (address) {
    return address(_underlying);
  }

  /// @inheritdoc IEmptyVault
  function pool() external view override returns (address) {
    return address(_pool);
  }

  /// @inheritdoc IEmptyVault
  function vault() external view override returns (address) {
    return address(_vault);
  }

  /// @inheritdoc IEmptyVault
  function name() external view override returns (string memory) {
    return _name;
  }

  /*
   * PRIVATE STATE CHANGING FUNCTIONS
   */

  /// @dev Harvest FARM and convert FARM -> WETH
  function _performHarvest() internal {
    if (_earnedETH() == 0) return;

    _pool.getReward();

    uint256 farm = IERC20(FarmAddress).balanceOf(address(this));
    uint256 out = _ethOut(farm);
    if (out == 0) return;

    IERC20(FarmAddress).safeIncreaseAllowance(RouterAddress, farm);
    IUniswapV2Router02(RouterAddress).swapExactTokensForTokens(
      farm,
      out,
      _path(),
      address(this),
      block.timestamp.add(1)
    );

    _totalETH = _totalETH.add(out);
  }

  /// @dev Calculate ETH & debt for address
  /// @param who Address to calculate debt for
  /// @param shares Shares of address used in debt formula
  /// @param total Total shares used in debt formula
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

  /*
   * PRIVATE STATE READING FUNCTIONS
   */

  /// @dev Get current earned WETH
  /// @return ethOut Amount of WETH to be received from swap
  function _earnedETH() internal view returns (uint256 ethOut) {
    uint256 earnedAmount = _pool.earned(address(this)).add(IERC20(FarmAddress).balanceOf(address(this)));

    if (earnedAmount == 0) return 0;

    ethOut = _ethOut(earnedAmount);
  }

  /// @dev Calculate received WETH from swap
  /// @param amount Amount of FARM to swap
  /// @return ethOut Amount of WETH to be received from swap of certain amount of FARM
  function _ethOut(uint256 amount) internal view returns (uint256 ethOut) {
    uint256[] memory amounts = IUniswapV2Router02(RouterAddress).getAmountsOut(amount, _path());
    ethOut = amounts[amounts.length.sub(1)];
  }

  /*
   * PRIVATE PURE FUNCTIONS
   */

  /// @dev Get path to WETH
  /// @return path Path from FARM to WETH
  function _path() internal pure returns (address[] memory path) {
    path = new address[](2);
    path[0] = FarmAddress;
    path[1] = WethAddress;
  }

  /// @dev ETH debt calculation formula
  /// @param eth Address to calculate debt for
  /// @param stake Shares of address used in debt formula
  /// @param totalStake Total shares used in debt formula
  function _calculateDebt(
    uint256 eth,
    uint256 stake,
    uint256 totalStake
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth).mul(2), totalStake);
  }

  /// @dev ETH calculation formula
  /// @param stake User's stake
  /// @param totalStake Total stake for vault
  /// @param eth Total ETH + debt stored
  /// @param ethDebt Amount of ETH debt for address
  function _calculateETH(
    uint256 stake,
    uint256 totalStake,
    uint256 eth,
    uint256 ethDebt
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth), totalStake).sub(ethDebt);
  }
}

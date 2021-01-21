// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

// External imports
import {TimelockController} from "@openzeppelin/contracts/access/TimelockController.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Context} from "@openzeppelin/contracts/GSN/Context.sol";

// Internal imports
import {IUniswapV2Pair} from "../Interfaces/Uniswap/IUniswapV2Pair.sol";
import {UniswapV2Library} from "../Libraries/UniswapV2Library.sol";
import {ShareMathLibrary} from "../Libraries/ShareMathLibrary.sol";
import {IHarvestVault} from "../Interfaces/IHarvestVault.sol";
import {ICurveSwap} from "../Interfaces/Curve/ICurveSwap.sol";
import {IHarvestPool} from "../Interfaces/IHarvestPool.sol";
import {IWETH} from "../Interfaces/Tokens/IWETH.sol";

struct VaultData {
  mapping(address => uint256) shares;
  mapping(address => uint256) debt;
  uint256 totalShares;
  uint256 totalETH;
  address[] acceptedTokens;
  address underlyingToken;
  VaultTokenConvert tokenConvert;
  bool active;
  bool old;
}

struct VaultTokenConvert {
  address converter;
  address conversionTarget;
  bool doConversion;
}

/**
 * @dev Main contract to manage the Empty ecosystem
 *
 * ▄▄▄ .• ▌ ▄ ·.  ▄▄▄·▄▄▄▄▄ ▄· ▄▌    .▄▄ · ▪   ▐ ▄  ▄▄ • ▄• ▄▌▄▄▌   ▄▄▄· ▄▄▄  ▪  ▄▄▄▄▄ ▄· ▄▌
 * ▀▄.▀··██ ▐███▪▐█ ▄█•██  ▐█▪██▌    ▐█ ▀. ██ •█▌▐█▐█ ▀ ▪█▪██▌██•  ▐█ ▀█ ▀▄ █·██ •██  ▐█▪██▌
 * ▐▀▀▪▄▐█ ▌▐▌▐█· ██▀· ▐█.▪▐█▌▐█▪    ▄▀▀▀█▄▐█·▐█▐▐▌▄█ ▀█▄█▌▐█▌██▪  ▄█▀▀█ ▐▀▀▄ ▐█· ▐█.▪▐█▌▐█▪
 * ▐█▄▄▌██ ██▌▐█▌▐█▪·• ▐█▌· ▐█▀·.    ▐█▄▪▐█▐█▌██▐█▌▐█▄▪▐█▐█▄█▌▐█▌▐▌▐█ ▪▐▌▐█•█▌▐█▌ ▐█▌· ▐█▀·.
 *  ▀▀▀ ▀▀  █▪▀▀▀.▀    ▀▀▀   ▀ •      ▀▀▀▀ ▀▀▀▀▀ █▪·▀▀▀▀  ▀▀▀ .▀▀▀  ▀  ▀ .▀  ▀▀▀▀ ▀▀▀   ▀ •
 */

contract EmptySingularity is Context {
  // Library implementations
  using EnumerableSet for EnumerableSet.AddressSet;
  using ShareMathLibrary for uint256;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Constants
  address public constant FarmEthPair = 0x56feAccb7f750B997B36A68625C7C596F0B41A58;
  address public constant FarmAddress = 0xa0246c9032bC3A600820415aE600c6388619A14D;
  address public constant WethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  uint256 public constant MIN_TIMELOCK = 2 days;
  uint256 public constant MAX_FEE = 100;
  uint256 public constant FEE = 10;

  // Public data
  address payable public dev;

  /**
   * @dev Vault data map
   * Pool address -> Vault data
   */
  mapping(address => VaultData) internal _vaults;

  // Ecosystem related contracts
  TimelockController internal _timelockController;

  /**
   * @dev Contract Initializer
   */
  constructor() public {
    address[] memory access = new address[](1);
    access[0] = _msgSender();

    _timelockController = new TimelockController(MIN_TIMELOCK, access, access);

    dev = _msgSender();
  }

  receive() external payable {}

  /**
   * MODIFIERS
   */

  modifier _performHarvest(address poolAddress) {
    (IHarvestPool pool, , IHarvestVault vault, IERC20 token, VaultData storage info) = _info(poolAddress);

    uint256 earnedAmount = pool.earned(address(this));

    if (earnedAmount > 0) {
      uint256 ethOut = _tokensOut(FarmEthPair, earnedAmount);

      if (ethOut > 0) {
        IERC20(FarmAddress).safeIncreaseAllowance(FarmEthPair, earnedAmount);
        IUniswapV2Pair(FarmEthPair).swap(earnedAmount, ethOut, address(this), new bytes(0));

        IERC20 weth = IERC20(WethAddress);
        uint256 calculatedFee = ethOut.mul(FEE).div(MAX_FEE);
        uint256 remainingWeth = ethOut.sub(calculatedFee);

        if (calculatedFee > 0) {
          weth.safeTransfer(dev, calculatedFee);
        }

        info.totalETH = info.totalETH.add(remainingWeth);
      }
    }

    _;
  }

  modifier _vaultActive(address poolAddress) {
    require(_vaults[poolAddress].active, "Vault not active");

    _;
  }

  /**
   * PUBLIC STATE CHANGING FUNCTIONS
   */

  function deposit(
    uint256 amount,
    address poolAddress,
    address to
  ) external _vaultActive(poolAddress) _performHarvest(poolAddress) returns (uint256) {
    address from = _msgSender();

    (IHarvestPool pool, address vaultAddress, IHarvestVault vault, IERC20 token, VaultData storage info) =
      _info(poolAddress);

    require(token.balanceOf(from) >= amount, "Not enough tokens");
    require(token.allowance(from, address(this)) >= amount, "Not enough allowance");

    uint256 originalAmount = token.balanceOf(address(this));

    token.safeTransferFrom(from, address(this), amount);

    uint256 realAmount = token.balanceOf(address(this)).sub(originalAmount);

    token.safeIncreaseAllowance(vaultAddress, realAmount);
    vault.deposit(realAmount);

    uint256 undepositedShares = vault.balanceOf(address(this));

    IERC20(vault).safeIncreaseAllowance(poolAddress, undepositedShares);
    pool.stake(undepositedShares);

    uint256 userShare =
      info.totalShares == 0 ? realAmount : realAmount.calculateShares(info.totalShares, _totalLocked(pool, vault));

    info.shares[to] = info.shares[to].add(userShare);
    info.totalShares = info.totalShares.add(userShare);

    uint256 ethDebt = info.totalETH == 0 ? 0 : _debt(info.totalETH, info.shares[to], info.totalShares);
    info.debt[to] = info.debt[to].add(ethDebt);
    info.totalETH = info.totalETH.add(ethDebt);

    return userShare.calculateAmount(info.totalShares, _totalLocked(pool, vault));
  }

  function withdraw(
    uint256 amount,
    address poolAddress,
    address payable to
  ) external _vaultActive(poolAddress) returns (uint256) {
    address from = _msgSender();

    require(balanceOf(poolAddress, from) >= amount, "Not enough balance");

    (IHarvestPool pool, , IHarvestVault vault, IERC20 token, VaultData storage info) = _info(poolAddress);

    claimETH(poolAddress, from, to);

    uint256 amountInShares = amount.calculateShares(vault.totalSupply(), vault.underlyingBalanceWithInvestment());
    uint256 userShare = amount.calculateShares(info.totalShares, _totalLocked(pool, vault));
    uint256 initialAmount = token.balanceOf(address(this));

    pool.withdraw(amountInShares);
    vault.withdraw(amountInShares);

    uint256 totalAmount = token.balanceOf(address(this)).sub(initialAmount);

    token.safeTransfer(to, totalAmount);

    info.shares[from] = info.shares[from].sub(userShare);
    info.totalShares = info.totalShares.sub(userShare);

    return totalAmount;
  }

  function claimETH(
    address poolAddress,
    address from,
    address payable to
  ) public _vaultActive(poolAddress) _performHarvest(poolAddress) returns (uint256) {
    IHarvestPool pool = IHarvestPool(poolAddress);
    address vaultAddress = pool.lpToken();
    VaultData storage info = _vaults[vaultAddress];
    IWETH weth = IWETH(WethAddress);

    uint256 earned = _getETH(info.shares[from], info.totalShares, info.totalETH, info.debt[from]);
    uint256 debt = info.debt[from];

    if (earned > 0) {
      info.totalETH = info.totalETH.sub(earned).sub(debt);

      uint256 ethDebt = info.totalETH == 0 ? 0 : _debt(info.totalETH, info.shares[to], info.totalShares);
      info.debt[to] = info.debt[to].add(ethDebt);
      info.totalETH = info.totalETH.add(ethDebt);

      weth.withdraw(earned);
      to.transfer(earned);
    }
  }

  /**
   * PUBLIC STATE READING FUNCTIONS
   */

  function tvl(address poolAddress) public view _vaultActive(poolAddress) returns (uint256) {
    IHarvestPool pool = IHarvestPool(poolAddress);
    address vaultAddress = pool.lpToken();
    return IHarvestVault(vaultAddress).underlyingBalanceWithInvestmentForHolder(address(this));
  }

  function earnedETH(address poolAddress, address who) public view _vaultActive(poolAddress) returns (uint256) {
    IHarvestPool pool = IHarvestPool(poolAddress);
    address vaultAddress = pool.lpToken();
    VaultData storage info = _vaults[vaultAddress];

    if (info.totalShares == 0) {
      return 0;
    }

    if (info.shares[who] == 0) {
      return 0;
    }

    return _getETH(info.shares[who], info.totalShares, info.totalETH + _earnedETH(pool), info.debt[who]);
  }

  function balanceOf(address poolAddress, address who) public view _vaultActive(poolAddress) returns (uint256) {
    IHarvestPool pool = IHarvestPool(poolAddress);
    address vaultAddress = pool.lpToken();
    VaultData storage info = _vaults[vaultAddress];

    if (info.totalShares == 0) {
      return 0;
    }

    if (info.shares[who] == 0) {
      return 0;
    }

    return
      info.shares[who].calculateAmount(
        info.totalShares,
        IHarvestVault(vaultAddress).underlyingBalanceWithInvestmentForHolder(address(this))
      );
  }

  // ONLY DEV
  function setDev(address payable newDev) public {
    require(_msgSender() == dev, "Not the dev");
    dev = newDev;
  }

  /**
   * PRIVATE STATE READING FUNCTIONS
   */

  function _totalLocked(IHarvestPool pool, IHarvestVault vault) internal view returns (uint256) {
    if (vault.totalSupply() == 0) {
      return 0;
    }

    return vault.underlyingBalanceWithInvestment().mul(pool.balanceOf(address(this))).div(vault.totalSupply());
  }

  function _earnedETH(IHarvestPool pool) internal view returns (uint256) {
    uint256 earnedAmount = pool.earned(address(this));

    if (earnedAmount == 0) {
      return 0;
    }

    uint256 ethOut = _tokensOut(FarmEthPair, earnedAmount);
    uint256 calculatedFee = ethOut.mul(FEE).div(MAX_FEE);
    uint256 remainingWeth = ethOut.sub(calculatedFee);

    return remainingWeth;
  }

  function _info(address poolAddress)
    internal
    view
    returns (
      IHarvestPool pool,
      address vaultAddress,
      IHarvestVault vault,
      IERC20 token,
      VaultData storage info
    )
  {
    pool = IHarvestPool(poolAddress);
    vaultAddress = pool.lpToken();
    vault = IHarvestVault(vaultAddress);
    token = IERC20(vault.underlying());
    info = _vaults[vaultAddress];
  }

  function _tokensOut(address pairAddress, uint256 amount) internal view returns (uint256) {
    (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress).getReserves();
    return UniswapV2Library.getAmountOut(amount, reserve0, reserve1);
  }

  function _debt(
    uint256 eth,
    uint256 stake,
    uint256 totalStake
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth).mul(2), totalStake);
  }

  function _getETH(
    uint256 stake,
    uint256 totalStake,
    uint256 eth,
    uint256 ethDebt
  ) internal pure returns (uint256) {
    return SafeMath.div(stake.mul(eth), totalStake).sub(ethDebt);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

// External imports
import {TimelockController} from "@openzeppelin/contracts/access/TimelockController.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Internal imports
import {EmptyVaultProxy} from "../Proxy/EmptyVaultProxy.sol";
import {IEmptyVault} from "../Vaults/IEmptyVault.sol";

struct VaultData {
  IEmptyVault vault;
  bool active;
  bool exists;
}

struct VaultInfo {
  address poolAddress;
  address emptyVaultAddress;
  address underlying;
  uint256 totalValueLocked;
  uint256 stakeBalance;
  uint256 underlyingBalance;
  uint256 claimableETH;
  bool active;
}

/**
 * @title Main managing contract for the Empty.fi systems
 * @author Affax
 *
 * ▄▄▄ .• ▌ ▄ ·.  ▄▄▄·▄▄▄▄▄ ▄· ▄▌    .▄▄ · ▪   ▐ ▄  ▄▄ • ▄• ▄▌▄▄▌   ▄▄▄· ▄▄▄  ▪  ▄▄▄▄▄ ▄· ▄▌
 * ▀▄.▀··██ ▐███▪▐█ ▄█•██  ▐█▪██▌    ▐█ ▀. ██ •█▌▐█▐█ ▀ ▪█▪██▌██•  ▐█ ▀█ ▀▄ █·██ •██  ▐█▪██▌
 * ▐▀▀▪▄▐█ ▌▐▌▐█· ██▀· ▐█.▪▐█▌▐█▪    ▄▀▀▀█▄▐█·▐█▐▐▌▄█ ▀█▄█▌▐█▌██▪  ▄█▀▀█ ▐▀▀▄ ▐█· ▐█.▪▐█▌▐█▪
 * ▐█▄▄▌██ ██▌▐█▌▐█▪·• ▐█▌· ▐█▀·.    ▐█▄▪▐█▐█▌██▐█▌▐█▄▪▐█▐█▄█▌▐█▌▐▌▐█ ▪▐▌▐█•█▌▐█▌ ▐█▌· ▐█▀·.
 *  ▀▀▀ ▀▀  █▪▀▀▀.▀    ▀▀▀   ▀ •      ▀▀▀▀ ▀▀▀▀▀ █▪·▀▀▀▀  ▀▀▀ .▀▀▀  ▀  ▀ .▀  ▀▀▀▀ ▀▀▀   ▀ •
 */

contract EmptySingularity is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;

  // Constants
  uint256 public constant MIN_TIMELOCK = 2 days;

  /**
   * @dev Vault data map
   * Pool address -> Vault data
   */
  mapping(address => VaultData) internal _vaults;
  EnumerableSet.AddressSet internal _vaultList;

  // Data
  address internal _dev;
  address internal _vaultTarget;
  TimelockController internal _timelockController;

  /**
   * @dev Contract Initializer
   */
  constructor() public {
    address[] memory access = new address[](1);

    _dev = _msgSender();
    access[0] = _dev;

    _timelockController = new TimelockController(MIN_TIMELOCK, access, access);
  }

  /*
   * EVENTS
   */

  event Deposit(address indexed from, address indexed to, address indexed pool, uint256 tokens, uint256 stake);

  event Withdraw(address indexed from, address indexed to, address indexed pool, uint256 tokens, uint256 stake);

  event ClaimETH(address indexed from, address indexed to, address indexed pool, uint256 eth);

  event CreateVault(address pool, address vault);

  event ChangeVaultState(address indexed pool, address indexed vault, bool active);

  /*
   * MODIFIERS
   */

  modifier _vaultActive(address poolAddress, bool activeCheck) {
    require(_vaults[poolAddress].exists, "Vault does not exist");
    require(_vaults[poolAddress].active || !activeCheck, "Vault not active");

    _;
  }

  /*
   * PUBLIC STATE CHANGING FUNCTIONS
   */

  function deposit(
    address poolAddress,
    uint256 amount,
    address to
  ) external _vaultActive(poolAddress, true) returns (uint256) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(amount > 0, "Nothing deposited");

    IERC20(vault.underlying()).safeTransferFrom(from, address(vault), amount);

    uint256 shares = vault.deposit(amount, to);

    emit Deposit(from, to, poolAddress, amount, shares);

    return shares;
  }

  function withdraw(
    address poolAddress,
    uint256 shares,
    address to
  ) external _vaultActive(poolAddress, false) returns (uint256) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(shares > 0, "Nothing withdrawn");
    require(vault.balanceOf(from) >= shares, "Not enough shares");

    (uint256 amount, uint256 eth) = vault.withdraw(from, shares, to);

    emit ClaimETH(from, to, poolAddress, eth);
    emit Withdraw(from, to, poolAddress, amount, shares);

    return amount;
  }

  function claimETH(address poolAddress, address to) public _vaultActive(poolAddress, false) returns (uint256) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(vault.earnedETH(from) > 0, "No earned eth");

    uint256 eth = vault.claimETH(from, to, vault.balanceOf(from), vault.totalShares());

    emit ClaimETH(from, to, poolAddress, eth);

    return eth;
  }

  function addPools(address[] memory pools) public onlyOwner returns (address[] memory) {
    address[] memory list = new address[](pools.length);

    for (uint256 index = 0; index < pools.length; index++) {
      address pool = pools[index];
      VaultData storage data = _vaults[pool];

      if (data.active) {
        list[index] = address(data.vault);
        continue;
      }

      if (data.exists) {
        list[index] = address(data.vault);
        data.active = true;

        emit ChangeVaultState(pool, address(data.vault), true);
        continue;
      }

      data.vault = IEmptyVault(address(new EmptyVaultProxy(address(this), pool)));
      data.exists = true;
      data.active = true;

      address vault = address(data.vault);

      _vaultList.add(pool);
      list[index] = vault;

      emit CreateVault(pool, vault);
      emit ChangeVaultState(pool, vault, true);
    }

    return list;
  }

  function deactivatePools(address[] memory pools) external onlyOwner {
    for (uint256 index = 0; index < pools.length; index++) {
      address pool = pools[index];
      VaultData storage data = _vaults[pool];

      if (!data.exists) continue;

      data.active = false;

      emit ChangeVaultState(pool, address(data.vault), false);
    }
  }

  function setVaultTarget(address target) external onlyOwner {
    _vaultTarget = target;
  }

  // ONLY DEV
  function setDev(address newDev) external {
    require(_msgSender() == _dev, "Not the dev");
    _dev = newDev;
  }

  /*
   * PUBLIC STATE READING FUNCTIONS
   */

  function tvl(address poolAddress) external view _vaultActive(poolAddress, false) returns (uint256) {
    IEmptyVault vault = _vaults[poolAddress].vault;

    return vault.tvl();
  }

  function earnedETH(address poolAddress, address who)
    external
    view
    _vaultActive(poolAddress, false)
    returns (uint256)
  {
    IEmptyVault vault = _vaults[poolAddress].vault;

    return vault.earnedETH(who);
  }

  function balanceOf(address poolAddress, address who)
    external
    view
    _vaultActive(poolAddress, false)
    returns (uint256)
  {
    IEmptyVault vault = _vaults[poolAddress].vault;

    return vault.balanceOf(who);
  }

  function underlyingBalanceOf(address poolAddress, address who)
    external
    view
    _vaultActive(poolAddress, false)
    returns (uint256)
  {
    IEmptyVault vault = _vaults[poolAddress].vault;

    return vault.underlyingBalanceOf(who);
  }

  function vaults() external view returns (address[] memory) {
    address[] memory list = new address[](_vaultList.length());

    for (uint256 index = 0; index < _vaultList.length(); index++) {
      list[index] = _vaultList.at(index);
    }

    return list;
  }

  function vaultInfos(address who) external view returns (VaultInfo[] memory) {
    VaultInfo[] memory list = new VaultInfo[](_vaultList.length());

    for (uint256 index = 0; index < _vaultList.length(); index++) {
      address pool = _vaultList.at(index);
      VaultData storage data = _vaults[pool];

      list[index] = VaultInfo(
        pool,
        address(data.vault),
        data.vault.underlying(),
        data.vault.tvl(),
        data.vault.balanceOf(who),
        data.vault.underlyingBalanceOf(who),
        data.vault.earnedETH(who),
        data.active
      );
    }

    return list;
  }

  function dev() external view returns (address) {
    return _dev;
  }

  function timelockController() external view returns (address) {
    return address(_timelockController);
  }

  function vaultTarget() external view returns (address) {
    return _vaultTarget;
  }
}

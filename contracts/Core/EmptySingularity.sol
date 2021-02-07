// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
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
 * ▄▄▄ .• ▌ ▄ ·.  ▄▄▄·▄▄▄▄▄ ▄· ▄▌    .▄▄ · ▪   ▐ ▄  ▄▄ • ▄• ▄▌▄▄▌   ▄▄▄· ▄▄▄  ▪  ▄▄▄▄▄ ▄· ▄▌
 * ▀▄.▀··██ ▐███▪▐█ ▄█•██  ▐█▪██▌    ▐█ ▀. ██ •█▌▐█▐█ ▀ ▪█▪██▌██•  ▐█ ▀█ ▀▄ █·██ •██  ▐█▪██▌
 * ▐▀▀▪▄▐█ ▌▐▌▐█· ██▀· ▐█.▪▐█▌▐█▪    ▄▀▀▀█▄▐█·▐█▐▐▌▄█ ▀█▄█▌▐█▌██▪  ▄█▀▀█ ▐▀▀▄ ▐█· ▐█.▪▐█▌▐█▪
 * ▐█▄▄▌██ ██▌▐█▌▐█▪·• ▐█▌· ▐█▀·.    ▐█▄▪▐█▐█▌██▐█▌▐█▄▪▐█▐█▄█▌▐█▌▐▌▐█ ▪▐▌▐█•█▌▐█▌ ▐█▌· ▐█▀·.
 *  ▀▀▀ ▀▀  █▪▀▀▀.▀    ▀▀▀   ▀ •      ▀▀▀▀ ▀▀▀▀▀ █▪·▀▀▀▀  ▀▀▀ .▀▀▀  ▀  ▀ .▀  ▀▀▀▀ ▀▀▀   ▀ •
 */

/// @title Emptyfi Singularity Contract
/// @author Affax
/// @dev Main commanding contract of Emptyfi ecosystem
/// In Code We Trust.
contract EmptySingularity is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeERC20 for IERC20;

  /*
   * VARIABLES
   */

  uint256 public constant MIN_TIMELOCK = 1 days;

  /// @dev Vault data map
  /// Pool address -> Vault data
  mapping(address => VaultData) internal _vaults;
  EnumerableSet.AddressSet internal _poolList;

  address internal _vaultTarget;
  TimelockController internal _timelockController;

  /// @dev Contract Initializer
  constructor() {
    address[] memory access = new address[](1);
    access[0] = _msgSender();
    _timelockController = new TimelockController(MIN_TIMELOCK, access, access);
  }

  /*
   * EVENTS
   */

  /// @dev Even fired when an address deposits into a vault
  /// @param from Address that initated deposit
  /// @param to Address that receives shares
  /// @param pool Address of underlying pool
  /// @param tokens Amount of underlying tokens deposited
  /// @param shares Amount of shares deposited
  event Deposit(address indexed from, address indexed to, address indexed pool, uint256 tokens, uint256 shares);

  /// @dev Even fired when an address withdraws from a vault
  /// @param from Address that initated withdraw
  /// @param to Address that receives tokens
  /// @param pool Address of underlying pool
  /// @param tokens Amount of underlying tokens withdrawn
  /// @param shares Amount of shares withdrawn
  event Withdraw(address indexed from, address indexed to, address indexed pool, uint256 tokens, uint256 shares);

  /// @dev Event fired when an address claims ETH
  /// @param from Address that initated claim
  /// @param to Address that receives ETH
  /// @param pool Address of underlying pool
  /// @param eth Amount of ETH claimed
  event ClaimETH(address indexed from, address indexed to, address indexed pool, uint256 eth);

  /// @dev Even fired when a new vault is created
  /// @param pool Address of underlying pool
  /// @param pool Address of vault
  event CreateVault(address pool, address vault);

  /// @dev Event fired when vault's active variable changes
  /// @param pool Address of underlying pool
  /// @param vault Address of vault
  /// @param active New state of vault
  event ChangeVaultState(address indexed pool, address indexed vault, bool active);

  /// @dev Event fired on setVaultTarget call
  /// @param target Address of vault logic contract
  event ChangeVaultTarget(address target);

  /*
   * MODIFIERS
   */

  /// @dev Do checks for vault before further logic
  /// @param poolAddress Address of pool vault is based on
  /// @param activeCheck Also check if vault is active
  modifier _vaultActive(address poolAddress, bool activeCheck) {
    require(_vaults[poolAddress].exists, "Vault does not exist");
    require(_vaults[poolAddress].active || !activeCheck, "Vault not active");

    _;
  }

  /*
   * PUBLIC STATE CHANGING FUNCTIONS
   */

  /// @dev Deposits & stakes user's asset into Harvest and gives them a share of the total pool
  /// @param poolAddress Address of pool to interact with
  /// @param amount Amount of tokens to stake
  /// @param to Address to give shares to
  /// @return shares amount of shares gotten
  /// @return eth Amount of ETH bonuses claimed from withdraw
  function deposit(
    address poolAddress,
    uint256 amount,
    address to
  ) public _vaultActive(poolAddress, true) returns (uint256 shares, uint256 eth) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(amount > 0, "Nothing deposited");

    IERC20(vault.underlying()).safeTransferFrom(from, address(vault), amount);

    (shares, eth) = vault.deposit(amount, to);

    emit ClaimETH(from, to, poolAddress, eth);
    emit Deposit(from, to, poolAddress, amount, shares);
  }

  /// @dev Unstakes & withdraws tokens from Harvest
  /// @param poolAddress Address of pool to interact with
  /// @param shares Amount of shares to withdraw
  /// @param to Address to give tokens to
  /// @return amount Amount of tokens withdrawed from Harvest vault
  /// @return eth Amount of ETH bonuses claimed from withdraw
  function withdraw(
    address poolAddress,
    uint256 shares,
    address to
  ) public _vaultActive(poolAddress, false) returns (uint256 amount, uint256 eth) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(shares > 0, "Nothing withdrawn");
    require(vault.balanceOf(from) >= shares, "Not enough shares");

    (amount, eth) = vault.withdraw(from, shares, to);

    emit ClaimETH(from, to, poolAddress, eth);
    emit Withdraw(from, to, poolAddress, amount, shares);
  }

  /// @dev Claims ETH for address
  /// @param poolAddress Address of pool to interact with
  /// @param to Address to receive WETH
  /// @return eth Amount of ETH claimed
  function claimETH(address poolAddress, address to) public _vaultActive(poolAddress, false) returns (uint256 eth) {
    IEmptyVault vault = _vaults[poolAddress].vault;
    address from = _msgSender();

    require(vault.earnedETH(from) > 0, "No earned eth");

    eth = vault.claimETH(from, to, vault.balanceOf(from), vault.totalShares());

    emit ClaimETH(from, to, poolAddress, eth);
  }

  /// @notice Controlled by TimelockController
  /// @dev Add new/enable pools
  /// @param pools Pools to base new vaults on
  /// @return vaultList Address list of created/enabled vaults
  function addPools(address[] memory pools) public onlyOwner returns (address[] memory vaultList) {
    vaultList = new address[](pools.length);

    for (uint256 index = 0; index < pools.length; index++) {
      address pool = pools[index];
      VaultData storage data = _vaults[pool];

      if (data.active) {
        vaultList[index] = address(data.vault);
        continue;
      }

      if (data.exists) {
        vaultList[index] = address(data.vault);
        data.active = true;

        emit ChangeVaultState(pool, address(data.vault), true);
        continue;
      }

      data.vault = IEmptyVault(address(new EmptyVaultProxy(address(this), pool)));
      data.exists = true;
      data.active = true;

      address vault = address(data.vault);

      _poolList.add(pool);
      vaultList[index] = vault;

      emit CreateVault(pool, vault);
      emit ChangeVaultState(pool, vault, true);
    }
  }

  /// @notice Controlled by TimelockController
  /// @dev Deactivate certain pools to disable depositing (won't stop withdraw or claims)
  /// @param pools Pools to deactivate
  function deactivatePools(address[] memory pools) external onlyOwner {
    for (uint256 index = 0; index < pools.length; index++) {
      address pool = pools[index];
      VaultData storage data = _vaults[pool];

      if (!data.exists) continue;

      data.active = false;

      emit ChangeVaultState(pool, address(data.vault), false);
    }
  }

  /// @notice Controlled by TimelockController
  /// @dev Set vault target to copy logic in proxies
  /// @param target New base vault address
  function setVaultTarget(address target) external onlyOwner {
    _vaultTarget = target;
    emit ChangeVaultTarget(target);
  }

  /*
   * PUBLIC STATE READING FUNCTIONS
   */

  /// @dev Get vault from pool address
  /// @param poolAddress Address of pool to interact with
  /// @return Vault address
  function getVault(address poolAddress) external view _vaultActive(poolAddress, false) returns (address) {
    return address(_vaults[poolAddress].vault);
  }

  /// @dev Get all pools in Emptyfi
  /// @return poolList List of pools
  function allPools() external view returns (address[] memory poolList) {
    poolList = new address[](_poolList.length());

    for (uint256 index = 0; index < _poolList.length(); index++) {
      poolList[index] = _poolList.at(index);
    }
  }

  /// @dev Get all info about vaults in Emptyfi
  /// @param who Address to get values on
  /// @return infoList List of vault infos
  function vaultInfos(address who) external view returns (VaultInfo[] memory infoList) {
    infoList = new VaultInfo[](_poolList.length());

    for (uint256 index = 0; index < _poolList.length(); index++) {
      address pool = _poolList.at(index);
      VaultData storage data = _vaults[pool];

      infoList[index] = VaultInfo(
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
  }

  /// @dev Get timelock controller address
  /// @return Timelock address
  function timelockController() external view returns (address) {
    return address(_timelockController);
  }

  /// @dev Get vault logic target address
  /// @return Target address
  function vaultTarget() external view returns (address) {
    return _vaultTarget;
  }

  /*
   * PUBLIC PURE FUNCTIONS
   */

  /// @dev Encode a setVaultTarget call
  /// @param target New base vault address
  /// @return Encoded setVaultTarget function data
  function encodeVaultTarget(address target) external pure returns (bytes memory) {
    return abi.encodeWithSelector(this.setVaultTarget.selector, target);
  }

  /// @dev Encode a addPools call
  /// @param pools Pools to base new vaults on
  /// @return Encoded addPools function data
  function encodeAddPools(address[] memory pools) external pure returns (bytes memory) {
    return abi.encodeWithSelector(this.addPools.selector, pools);
  }

  /// @dev Encode a deactivatePools call
  /// @param pools Pools to deactivate
  /// @return Encoded deactivatePools function data
  function encodeDeactivatePools(address[] memory pools) external pure returns (bytes memory) {
    return abi.encodeWithSelector(this.deactivatePools.selector, pools);
  }
}

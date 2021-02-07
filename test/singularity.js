const {
  accountPool,
  getWeth,
  parseTokens,
  useApproval,
  drain,
  checkExact,
  advanceNBlock,
  advanceTime,
  hoursToSeconds,
  underlyingBalanceOf,
} = require("./_tools.js");
const { wethAddress, usdcAddress } = require("./_constants");
const truffleAssert = require("truffle-assertions");
const pools = require("../lib/pools");

const TimelockController = artifacts.require("TestTimelockController");
const EmptySingularity = artifacts.require("EmptySingularity");
const EmptyVaultV1 = artifacts.require("EmptyVaultV1");
const IEmptyVault = artifacts.require("IEmptyVault");
const IERC20 = artifacts.require("IERC20");

contract(`Test singularity contract`, async (accounts) => {
  const pool = accountPool(accounts);

  let setup = false;

  let singularity;
  let vaultV1;

  let weth;
  let usdc;

  async function setupCoreProtocol() {
    if (setup) return;
    setup = true;

    singularity = await EmptySingularity.new();
    vaultV1 = await EmptyVaultV1.new();

    await singularity.setVaultTarget(vaultV1.address);
    await singularity.addPools(pools.pools);
    await singularity.transferOwnership(await singularity.timelockController());

    weth = await IERC20.at(wethAddress);
    usdc = await IERC20.at(usdcAddress);
  }

  beforeEach(async () => {
    await setupCoreProtocol();
  });

  pool("Should successfully stake WETH for account 1", async (account, from) => {
    const amount = parseTokens(1);
    const pool = pools.wethPool;

    await getWeth(account, amount);
    await useApproval(weth, singularity.address)(account);
    await singularity.deposit(pool, amount, account, from);

    checkExact(
      parseInt(amount),
      parseInt(await underlyingBalanceOf(singularity, pool, account)),
      0.01,
      "Stake calculation faulty for account 1"
    );
  });

  pool("Should successfully stake WETH for account 2", async (account, from) => {
    const amount = parseTokens(5);
    const pool = pools.wethPool;

    await getWeth(account, amount);
    await useApproval(weth, singularity.address)(account);
    await singularity.deposit(pool, amount, account, from);

    checkExact(
      parseInt(amount),
      parseInt(await underlyingBalanceOf(singularity, pool, account)),
      0.01,
      "Stake calculation faulty for account 2"
    );
  });

  pool("Should successfully stake and unstake half USDC", async (account, from) => {
    const amount = parseTokens(4000, 6);
    const pool = pools.usdcPool;

    await useApproval(usdc, singularity.address)(account);
    await drain(usdc, "0xBE0eB53F46cd790Cd13851d5EFf43D12404d33E8", account, amount);

    await singularity.deposit(pool, amount, account, from);

    checkExact(
      parseInt(amount),
      parseInt(await underlyingBalanceOf(singularity, pool, account)),
      0.01,
      "Stake calculation faulty for USDC staking"
    );

    const vault = await IEmptyVault.at(await singularity.getVault(pool));
    const shares = parseInt(await vault.balanceOf(account));
    const halfShares = shares / 2;

    await singularity.withdraw(pool, halfShares, account, from);

    checkExact(
      parseInt(amount) / 2,
      parseInt(await underlyingBalanceOf(singularity, pool, account)),
      0.01,
      "Stake calculation faulty for USDC unstaking"
    );
  });

  pool("Should claim earned eth from WETH pool for account 3", async (account, from) => {
    const amount = parseTokens(12);
    const pool = pools.wethPool;

    await getWeth(account, amount);
    await useApproval(weth, singularity.address)(account);
    await singularity.deposit(pool, amount, account, from);

    checkExact(
      parseInt(amount),
      parseInt(await underlyingBalanceOf(singularity, pool, account)),
      0.01,
      "Stake calculation faulty for account 3"
    );

    for (let index = 0; index < 10; index++) {
      await advanceNBlock(100);
    }

    const vault = await IEmptyVault.at(await singularity.getVault(pool));
    const expected = parseInt(await vault.earnedETH(account));
    const initialWeth = parseInt(await weth.balanceOf(account));

    const tx = await singularity.claimETH(pool, account, from);

    const earned = parseInt(tx.logs[0].args["3"]);
    const claimedWeth = parseInt(await weth.balanceOf(account));
    const realEarned = claimedWeth - initialWeth;

    assert.notEqual(initialWeth, claimedWeth, "Didn't receive WETH from ETH bonus");
    assert.isAtLeast(earned, expected, "Received ETH didn't match up with expectations");
    assert.equal(realEarned, earned, "Received ETH didn't match up with calculations");
  });

  pool("Should update vault logic only on timelock call", async (_, from) => {
    const newVault = await EmptyVaultV1.new();
    const creatorFrom = { from: accounts[0] };

    await truffleAssert.reverts(singularity.setVaultTarget(newVault.address, from));
    await truffleAssert.reverts(singularity.setVaultTarget(newVault.address, creatorFrom));

    const timelock = await TimelockController.at(await singularity.timelockController());
    const callData = await singularity.encodeVaultTarget(newVault.address);
    const data = [singularity.address, 0, callData, "0x0", "0x0"];
    const scheduleData = [...data, 86400];

    await truffleAssert.reverts(timelock.schedule(...scheduleData, from));
    await timelock.schedule(...scheduleData, creatorFrom);
    await truffleAssert.reverts(timelock.execute(...data, from));
    await truffleAssert.reverts(timelock.execute(...data, creatorFrom));

    await advanceTime(hoursToSeconds(25));

    await truffleAssert.reverts(timelock.execute(...data, from));
    await timelock.execute(...data, creatorFrom);

    assert.equal(newVault.address, await singularity.vaultTarget(), "Vault target not matching up with new vault");
  });
});

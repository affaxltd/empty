const { burnAddress, maxPermit, wethAddress } = require("./_constants");
const { time } = require("@openzeppelin/test-helpers");

const IEmptyVault = artifacts.require("IEmptyVault");
const Weth = artifacts.require("IWETH");

const parseTokens = (amount, decimals = 18) => {
  return (BigInt(10) ** BigInt(decimals) * BigInt(amount)).toString();
};

const burn = async (token, account) => {
  await token.transfer(burnAddress, await token.balanceOf(account), {
    from: account,
  });
};

const useApproval = (token, address) => {
  return async function approve(account) {
    await token.approve(address, maxPermit, {
      from: account,
    });
  };
};

const accountPool = (accounts) => {
  let index = 0;
  return function (title, func) {
    it(title, () => {
      index++;
      return func(accounts[index - 1], { from: accounts[index - 1] });
    });
  };
};

const drain = async (token, from, to, amount) => {
  await web3.eth.sendTransaction({
    from: to,
    to: from,
    value: parseTokens(1),
  });

  await token.transfer(to, amount, {
    from,
  });
};

const getWeth = async (account, amount) => {
  const instance = await Weth.at(wethAddress);

  await instance.deposit({
    value: amount,
    from: account,
  });
};

const checkExact = (a, b, max, msg) => {
  const difference = Math.abs(a - b);
  const maxDifference = a * max;

  assert.notEqual(Math.min(maxDifference, difference), maxDifference, msg);
};

const advanceNBlock = async (n) => {
  const startingBlock = await time.latestBlock();
  await time.increase(15 * Math.round(n));
  const endBlock = startingBlock.addn(n);
  await time.advanceBlockTo(endBlock);
};

const advanceTime = async (t) => {
  await time.increase(t);
};

const hoursToSeconds = (h) => {
  return h * 60 * 60;
};

const underlyingBalanceOf = async (singularity, pool, account) => {
  const vault = await IEmptyVault.at(await singularity.getVault(pool));
  return await vault.underlyingBalanceOf(account);
};

module.exports = {
  parseTokens,
  burn,
  useApproval,
  accountPool,
  drain,
  getWeth,
  checkExact,
  advanceNBlock,
  advanceTime,
  hoursToSeconds,
  underlyingBalanceOf,
};

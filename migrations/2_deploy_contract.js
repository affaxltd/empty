const EmptySingularity = artifacts.require("EmptySingularity");
const EmptyVaultV1 = artifacts.require("EmptyVaultV1");

const pools = require("../lib/pools");

module.exports = async function (deployer) {
  await deployer.deploy(EmptySingularity);
  await deployer.deploy(EmptyVaultV1);

  const singularity = await EmptySingularity.deployed();
  const vault = await EmptyVaultV1.deployed();

  await singularity.setVaultTarget(vault.address);
  await singularity.addPools(pools.pools);
  await singularity.transferOwnership(await singularity.timelockController());
};

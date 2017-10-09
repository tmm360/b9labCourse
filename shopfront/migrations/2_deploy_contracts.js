var CollectHub = artifacts.require("./CollectHub.sol");
var MetaCoin = artifacts.require("./MetaCoin.sol");
var Shopfront = artifacts.require("./Shopfront.sol");

module.exports = async function(deployer) {
  await deployer.deploy(MetaCoin);
  await deployer.deploy(Shopfront);
  await deployer.deploy(CollectHub, Shopfront.address);
};

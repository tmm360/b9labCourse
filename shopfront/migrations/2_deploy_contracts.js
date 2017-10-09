var CollectHub = artifacts.require("./CollectHub.sol");
var MetaCoinERC20 = artifacts.require("./MetaCoinERC20.sol");
var Shopfront = artifacts.require("./Shopfront.sol");

module.exports = async function(deployer) {
  await deployer.deploy(MetaCoinERC20);
  await deployer.deploy(Shopfront, MetaCoinERC20.address);
  await deployer.deploy(CollectHub, Shopfront.address);
};

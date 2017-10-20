var CollectHub = artifacts.require("./CollectHub.sol");
var MetaCoinERC20 = artifacts.require("./MetaCoinERC20.sol");
var Shopfront = artifacts.require("./Shopfront.sol");

module.exports = function(deployer) {
  deployer.deploy(MetaCoinERC20).then(() =>
    deployer.deploy(Shopfront, MetaCoinERC20.address).then(() =>
      deployer.deploy(CollectHub, Shopfront.address)));
};

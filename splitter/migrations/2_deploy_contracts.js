var Splitter = artifacts.require("./Splitter.sol");

module.exports = function(deployer) {
    deployer.deploy(Splitter, "0x14723a09acff6d2a60dcdf7aa4aff308fddc160c", "0x4b0897b0513fdc7c541b6d9d7e929c4e5364d2db");
};

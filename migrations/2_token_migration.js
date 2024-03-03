const RoyaltyNFT = artifacts.require("RoyaltyNFT");

module.exports = function (deployer) {
  deployer.deploy(RoyaltyNFT);
};
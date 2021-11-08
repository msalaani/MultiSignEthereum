const MultiSign = artifacts.require("MultiSign");

module.exports = function (deployer) {
	var accounts = web3.eth.getAccounts()
	deployer.deploy(MultiSign, accounts, 1);
};

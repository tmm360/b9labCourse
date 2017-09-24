const expectedExceptionPromise = require("../../helpers/test/expectedExceptionPromise.js");
const promisify = require('js-promisify');
const Splitter = artifacts.require("./Splitter.sol");

contract('Splitter', accounts => {
    const address1 = "0xBeB2A06Eb48AcDd0e4C23B6740E04c495856fA08";
    const address2 = "0x79D5D78b75469d06f06ce56A69890eDe014112E9";
    const getGasCost = (txInfo, gasPrice) => gasPrice.mul(txInfo.receipt.cumulativeGasUsed);

    var instance;
    
    beforeEach(() => Splitter.new()
        .then(_instance => instance = _instance));

    it("Should set owner", () => {
        return instance.owner.call({ from: accounts[0] })
            .then(result => assert.equal(result, accounts[0], "Owner is wrong"))
    });

    it("Should kill from owner", () => {
        return instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return instance.kill({ from: accounts[0] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isTrue(result, "Should be killed"))
    });

    it("Should not kill from not owner", () => {
        return instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return expectedExceptionPromise(() =>
                    instance.kill({ from: accounts[1] }));
            })
    });

    it("Should split with addresses", () => {
        return instance.split(address1, address2, { from: accounts[0], value: 1000 })
            .then(txInfo => instance.balances.call(address1, { from: accounts[0] }))
            .then(result => {
                assert.equal(result, 500, "Address1 balance is wrong");
                return instance.balances.call(address2, { from: accounts[0] });
            })
            .then(result => assert.equal(result, 500, "Address2 balance is wrong"))
    });

    it("Should not split if killed", () => {
        return instance.kill({ from: accounts[0] })
            .then(txInfo => expectedExceptionPromise(() =>
                instance.split(address1, address2, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000))
    });

    it("Should not split with wrong receivers", () => {
        return expectedExceptionPromise(() =>
                instance.split("", address2, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000)
            .then(() => expectedExceptionPromise(() =>
                instance.split(address1, "", { from: accounts[0], value: 1000, gas: 3000000 }), 3000000));
    });

    it("Should withdraw owned balance", () => {
        var accountBalanceStep0;
        var accountBalanceStep1;
        var accountBalanceStep2;
        var web3GasPrice;
        var withdrawTxInfo1;
        var withdrawTxInfo2;

        return promisify(web3.eth.getGasPrice, [])
            .then(_gasPrice => {
                web3GasPrice = _gasPrice;
                return promisify(web3.eth.getBalance, [accounts[1]]);
            })
            .then(balance => {
                accountBalanceStep0 = balance;
                return instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 })
            })
            .then(txInfo => instance.withdraw({ from: accounts[1], gasPrice: web3GasPrice }))
            .then(txInfo => {
                withdrawTxInfo1 = txInfo;
                return promisify(web3.eth.getBalance, [accounts[1]]);
            })
            .then(balance => {
                accountBalanceStep1 = balance;

                assert.deepEqual(accountBalanceStep1,
                    accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(500),
                    "Balance is wrong after first withdraw");

                return instance.withdraw({ from: accounts[1], gasPrice: web3GasPrice });
            })
            .then(txInfo => {
                withdrawTxInfo2 = txInfo;
                return promisify(web3.eth.getBalance, [accounts[1]]);
            })
            .then(balance => {
                accountBalanceStep2 = balance;

                assert.deepEqual(accountBalanceStep2,
                    accountBalanceStep1.sub(getGasCost(withdrawTxInfo2, web3GasPrice)),
                    "Balance is wrong after second withdraw");
            })
    });
})
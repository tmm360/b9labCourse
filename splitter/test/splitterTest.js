const expectedExceptionPromise = require("../../helpers/test/expected_exception_testRPC_and_geth.js");
var Splitter = artifacts.require("./Splitter.sol");

contract('Splitter', accounts => {
    const bobAddress = "0xBeB2A06Eb48AcDd0e4C23B6740E04c495856fA08";
    const carolAddress = "0x79D5D78b75469d06f06ce56A69890eDe014112E9";

    var instance;
    
    beforeEach(() => Splitter.new(bobAddress, carolAddress)
        .then(_instance => instance = _instance));

    it("Should set Bob and Carol addresses", () => {
        return instance.bobAddress.call({ from: accounts[0] })
            .then(result => {
                assert.equal(result, bobAddress.toLowerCase(), "Bob address is wrong");
                return instance.carolAddress.call({ from: accounts[0] });
            })
            .then(result => assert.equal(result, carolAddress.toLowerCase(), "Carol address is wrong"))
    });

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
                return instance.kill({ from: accounts[1] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isFalse(result, "Should not be killed"))
    });

    it("Should split with addresses", () => {
        var address1 = "0x2836C2B0fBf18Bc8e889Ba4782d76fAFed5cfC13";
        var address2 = "0xabCEbb26FFC6dF88b0D2E7F73f00f7883D1bfd5d";

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
                instance.sendTransaction({ from: accounts[0], value: 1000, gas: 3000000 }), 3000000))
    });

    it("Should withdraw owned balance", () => {
        var accountBalanceStep0 = web3.eth.getBalance(accounts[1]);
        var accountBalanceStep1;
        var accountBalanceStep2;

        var getGasCost = txInfo => web3.eth.gasPrice.mul(txInfo.receipt.cumulativeGasUsed);

        return instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 })
            .then(txInfo => instance.withdraw({ from: accounts[1], gasPrice: web3.eth.gasPrice }))
            .then(txInfo => {
                accountBalanceStep1 = web3.eth.getBalance(accounts[1]);

                assert.deepEqual(accountBalanceStep1,
                    accountBalanceStep0.sub(getGasCost(txInfo)).add(500),
                    "Balance is wrong after first withdraw");

                return instance.withdraw({ from: accounts[1], gasPrice: web3.eth.gasPrice });
            })
            .then(txInfo => {
                accountBalanceStep2 = web3.eth.getBalance(accounts[1]);

                assert.deepEqual(accountBalanceStep2,
                    accountBalanceStep1.sub(getGasCost(txInfo)),
                    "Balance is wrong after second withdraw");
            })
    });

    it("Should split with fallback", () => {
        return instance.sendTransaction({ from: accounts[0], value: 1000 })
            .then(txInfo => instance.balances.call(bobAddress, { from: accounts[0] }))
            .then(result => {
                assert.equal(result, 500, "Bob balance is wrong");
                return instance.balances.call(carolAddress, { from: accounts[0] });
            })
            .then(result => assert.equal(result, 500, "Carol balance is wrong"))
    });
})
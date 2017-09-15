const expectedExceptionPromise = require("./helpers/expected_exception_testRPC_and_geth.js");
var Splitter = artifacts.require("./Splitter.sol");

var bobAddress = "0xBeB2A06Eb48AcDd0e4C23B6740E04c495856fA08";
var carolAddress = "0x79D5D78b75469d06f06ce56A69890eDe014112E9";

contract('Splitter', accounts => {
    var instance;

    beforeEach(() => Splitter.new(bobAddress, carolAddress)
        .then(_instance => instance = _instance));

    it("Should set Bob and Carol addresses", () =>
        instance.bobAddress.call({ from: accounts[0] })
            .then(result => {
                assert.equal(result, bobAddress.toLowerCase(), "Bob address is wrong");
                return instance.carolAddress.call({ from: accounts[0] });
            })
            .then(result => assert.equal(result, carolAddress.toLowerCase(), "Carol address is wrong"))
    );

    it("Should set owner", () =>
        instance.owner.call({ from: accounts[0] })
            .then(result => assert.equal(result, accounts[0], "Owner is wrong"))
    );

    it("Should kill from owner", () =>
        instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return instance.kill({ from: accounts[0] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isTrue(result, "Should be killed"))
    );

    it("Should not kill from not owner", () =>
        instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return instance.kill({ from: accounts[1] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isFalse(result, "Should not be killed"))
    );

    it("Should split with addresses", () => {
        var address1 = "0x2836C2B0fBf18Bc8e889Ba4782d76fAFed5cfC13";
        var address2 = "0xabCEbb26FFC6dF88b0D2E7F73f00f7883D1bfd5d";

        return instance.split(address1, address2, { from: accounts[0], value: 1000 })
            .then(txInfo => instance.getBalance.call(address1, { from: accounts[0] }))
            .then(result => {
                assert.equal(result, 500, "Address1 balance is wrong");
                return instance.getBalance.call(address2, { from: accounts[0] });
            })
            .then(result => assert.equal(result, 500, "Address2 balance is wrong"))
    });

    it("Should not split if killed", () =>
        instance.kill({ from: accounts[0] })
            .then(txInfo => expectedExceptionPromise(() =>
                instance.sendTransaction({ from: accounts[0], value: 1000, gas: 3000000 }), 3000000))
    );

    it("Should withdraw owned balance", () =>
    {
        var accountBalanceStep0 = web3.eth.getBalance(accounts[1]);
        var accountBalanceStep1;
        var accountBalanceStep2;

        var getGasCost = txInfo => txInfo.receipt.cumulativeGasUsed * web3.eth.gasPrice;

        instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 })
            .then(txInfo => instance.withdraw({ from: accounts[1], gasPrice: web3.eth.gasPrice }))
            .then(txInfo => {
                accountBalanceStep1 = web3.eth.getBalance(accounts[1]);

                assert.equal(accountBalanceStep1,
                    accountBalanceStep0 - getGasCost(txInfo) + 500,
                    "Balance is wrong after first withdraw");

                return instance.withdraw({ from: accounts[1], gasPrice: web3.eth.gasPrice });
            })
            .then(txInfo => {
                accountBalanceStep2 = web3.eth.getBalance(accounts[1]);

                assert.equal(accountBalanceStep2,
                    accountBalanceStep1 - getGasCost(txInfo),
                    "Balance is wrong after second withdraw");
                
                // THIS SHOULD NOT PASS!
                assert.equal(accountBalanceStep2,
                    accountBalanceStep1 - getGasCost(txInfo) + 500,
                    "THIS SHOULD NOT PASS");
            })
    });

    it("Should split with fallback", () =>
        instance.sendTransaction({ from: accounts[0], value: 1000 })
            .then(txInfo => instance.getBalance.call(bobAddress, { from: accounts[0] }))
            .then(result => {
                assert.equal(result, 500, "Bob balance is wrong");
                return instance.getBalance.call(carolAddress, { from: accounts[0] });
            })
            .then(result => assert.equal(result, 500, "Carol balance is wrong"))
    );
})
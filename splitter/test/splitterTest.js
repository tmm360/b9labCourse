"use strict";

const expectedExceptionPromise = require("../../helpers/test/expectedExceptionPromise.js");
const promisify = require('js-promisify');
const Splitter = artifacts.require("./Splitter.sol");

contract('Splitter', accounts => {
    const address1 = "0xBeB2A06Eb48AcDd0e4C23B6740E04c495856fA08";
    const address2 = "0x79D5D78b75469d06f06ce56A69890eDe014112E9";
    const getGasCost = (txInfo, gasPrice) => gasPrice.mul(txInfo.receipt.cumulativeGasUsed);

    let instance;
    
    beforeEach(async () => instance = await Splitter.new());

    it("should set owner", async () => {
        let owner = await instance.owner.call({ from: accounts[0] });
        assert.equal(owner, accounts[0], "Owner is wrong");
    });

    it("should pause from owner", async () => {
        await instance.setPause(true, { from: accounts[0] });

        assert.isTrue(await instance.isPaused.call({ from: accounts[0] }), "Is not paused");

        await instance.setPause(false, { from: accounts[0] });

        assert.isFalse(await instance.isPaused.call({ from: accounts[0] }), "Is still paused");
    });

    it("should not kill from not owner", async () => {
        await expectedExceptionPromise(
            () => instance.setPause(true, { from: accounts[1], gas: 3000000 }), 3000000);
    });

    it("should split", async () => {
        await instance.split(address1, address2, { from: accounts[0], value: 1000 });

        assert.equal(await instance.balances.call(address1, { from: accounts[0] }),
            500, "Address1 balance is wrong");
        assert.equal(await instance.balances.call(address2, { from: accounts[0] }),
            500, "Address2 balance is wrong");
    });

    it("should not split if killed", async () => {
        await instance.setPause(true, { from: accounts[0] });
        await expectedExceptionPromise(() =>
            instance.split(address1, address2, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });

    it("should not split if wrong receivers", async () => {
        await expectedExceptionPromise(() =>
            instance.split("", address2, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
        await expectedExceptionPromise(() =>
            instance.split(address1, "", { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });

    it("should withdraw owned balance", async () => {
        let web3GasPrice = await promisify(web3.eth.getGasPrice, []);
        let accountBalanceStep0 = await promisify(web3.eth.getBalance, [accounts[1]]);

        await instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 });
        
        let withdrawTxInfo1 = await instance.withdraw({ from: accounts[1], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await promisify(web3.eth.getBalance, [accounts[1]]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(500),
            "Balance is wrong after first withdraw");

        await expectedExceptionPromise(() =>
            instance.withdraw({ from: accounts[1], gas: 3000000 }), 3000000);
    });
})
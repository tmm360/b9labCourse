"use strict";

const expectedExceptionPromise = require("../../helpers/test/expectedExceptionPromise.js");
const Promise = require("bluebird");
const Splitter = artifacts.require("./Splitter.sol");

Promise.promisifyAll(web3.eth);

contract('Splitter', accounts => {
    const getGasCost = (txInfo, gasPrice) => gasPrice.mul(txInfo.receipt.cumulativeGasUsed);

    let instance;
    
    beforeEach(async () => instance = await Splitter.new());

    it("should set owner", async () => {
        let owner = await instance.owner.call({ from: accounts[0] });
        assert.equal(owner, accounts[0], "Owner is wrong");
    });

    it("should pause from owner", async () => {
        await instance.switchPause({ from: accounts[0] });

        assert.isTrue(await instance.isPaused.call({ from: accounts[0] }), "Is not paused");

        await instance.switchPause({ from: accounts[0] });

        assert.isFalse(await instance.isPaused.call({ from: accounts[0] }), "Is still paused");
    });

    it("should not pause from not owner", async () => {
        await expectedExceptionPromise(
            () => instance.switchPause({ from: accounts[1], gas: 3000000 }), 3000000);
    });

    it("should split", async () => {
        await instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 });

        assert.equal(await instance.balances.call(accounts[1], { from: accounts[0] }),
            500, "Address1 balance is wrong");
        assert.equal(await instance.balances.call(accounts[2], { from: accounts[0] }),
            500, "Address2 balance is wrong");
    });

    it("should not split if paused", async () => {
        await instance.switchPause({ from: accounts[0] });
        await expectedExceptionPromise(() =>
            instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });

    it("should not split if wrong receivers", async () => {
        await expectedExceptionPromise(() =>
            instance.split("", accounts[2], { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
        await expectedExceptionPromise(() =>
            instance.split(accounts[1], "", { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });

    it("should withdraw owned balance", async () => {
        let web3GasPrice = await web3.eth.getGasPriceAsync();
        let accountBalanceStep0 = await web3.eth.getBalanceAsync(accounts[1]);

        await instance.split(accounts[1], accounts[2], { from: accounts[0], value: 1000 });
        
        let withdrawTxInfo1 = await instance.withdraw({ from: accounts[1], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await web3.eth.getBalanceAsync(accounts[1]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(500),
            "Balance is wrong after first withdraw");

        await expectedExceptionPromise(() =>
            instance.withdraw({ from: accounts[1], gas: 3000000 }), 3000000);
    });
})
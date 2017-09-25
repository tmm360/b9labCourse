"use strict";

const expectedExceptionPromise = require("../../helpers/test/expectedExceptionPromise.js");
const promisify = require('js-promisify');
const sha3 = require('js-sha3');
const Remittance = artifacts.require("./Remittance.sol");

function wait(ms) {
    let start = Date.now(),
        now = start;
    while (now - start < ms)
        now = Date.now();
}

contract('Remittance', accounts => {
    const getGasCost = (txInfo, gasPrice) => gasPrice.mul(txInfo.receipt.cumulativeGasUsed);
    const keccak256 = obj => "0x" + sha3.keccak256(obj);
    const hash1 = keccak256("test");
    const hash2 = keccak256("test2");

    let instance;

    beforeEach(async () => instance = await Remittance.new());

    it("should set owner", async () => {
        let owner = await instance.owner.call({ from: accounts[0] });
        assert.equal(owner, accounts[0], "Owner is wrong");
    });

    it("should update password hash", async () => {
        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        let deposit = await instance.deposits.call(accounts[0], hash1, { from: accounts[0] });

        await instance.changePswsHash(hash1, hash2, { from: accounts[0] });
        
        assert.deepEqual(
            await instance.deposits.call(accounts[0], hash2, { from: accounts[0] }),
            deposit, "Has not been moved");
        assert.deepEqual(
            await instance.deposits.call(accounts[0], hash1, { from: accounts[0] }),
            [new web3.BigNumber(0), new web3.BigNumber(0), new web3.BigNumber(0)],
            "Previous hash has not been deleted");
    });

    it("should not update password hash if the new hash is already used", async () => {
        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        await instance.deposit(hash2, 100, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.changePswsHash(hash1, hash2, { from: accounts[0], gas: 3000000 }), 3000000);
    })

    it("should deposit new founds", async () => {
        let depositTx = await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        let depositBlock = await promisify(web3.eth.getBlock, [depositTx.receipt.blockNumber]);
        let blockTimestamp = depositBlock.timestamp;

        assert.deepEqual(await instance.deposits.call(accounts[0], hash1, { from: accounts[0] }),
            [new web3.BigNumber(990 /* 1000 - 1% */),
             new web3.BigNumber(blockTimestamp),
             new web3.BigNumber(blockTimestamp + 100)],
            "Didn't create deposit");
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(10), "Fees has not been deposited");
    });

    it("should not deposit if paused", async () => {
        await instance.setPause(true, { from: accounts[0] });
        await expectedExceptionPromise(() =>
            instance.deposit(hash1, 100, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });
    
    it("should not deposit if duration is over max limit", async () => {
        await expectedExceptionPromise(() =>
            instance.deposit(hash1, 5184000 /*60 days*/, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000)
    });
    
    it("should not deposit if already deposited", async () => {
        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        await expectedExceptionPromise(() =>
            instance.deposit(hash1, 100, { from: accounts[0], value: 2000, gas: 3000000 }), 3000000);
    });

    it("should be paused from owner", async () => {
        await instance.setPause(true, { from: accounts[0] });
        
        assert.isTrue(await instance.isPaused.call({ from: accounts[0] }), "Has not been paused")

        await instance.setPause(false, { from: accounts[0] });
        
        assert.isFalse(await instance.isPaused.call({ from: accounts[0] }), "Has not been unpaused")
    });

    it("should not be paused from not owner", async () => {
        await expectedExceptionPromise(() =>
            instance.setPause(true, { from: accounts[1], gas: 3000000 }), 3000000);
    });

    it("should withdraw deposit with passwords", async () => {
        let web3GasPrice = await promisify(web3.eth.getGasPrice, []);
        let accountBalanceStep0 = await promisify(web3.eth.getBalance, [accounts[1]]);

        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        
        let withdrawTxInfo1 = await instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[1], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await promisify(web3.eth.getBalance, [accounts[1]]);

        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(990),
            "Balance is wrong after first withdraw");

        await expectedExceptionPromise(() =>
            instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[1], gasPrice: web3GasPrice, gas: 3000000 }), 3000000);
    });

    it("should not withdraw with passwords if expired", async () => {
        await instance.deposit(hash1, 1, { from: accounts[0], value: 1000 });
        wait(2000);

        await expectedExceptionPromise(() =>
            instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[0], gas: 3000000 }), 3000000);
    });

    it("should withdraw deposit as expired if author", async () => {
        let web3GasPrice = await promisify(web3.eth.getGasPrice, []);

        await instance.deposit(hash1, 1, { from: accounts[0], value: 1000 });
        let accountBalanceStep0 = await promisify(web3.eth.getBalance, [accounts[0]]);
        wait(2000);
        
        let withdrawTxInfo1 = await instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await promisify(web3.eth.getBalance, [accounts[0]]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(990),
            "Balance is wrong after first withdraw");

        let withdrawTxInfo2 = await instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep2 = await promisify(web3.eth.getBalance, [accounts[0]]);
        
        assert.deepEqual(accountBalanceStep2,
            accountBalanceStep1.sub(getGasCost(withdrawTxInfo2, web3GasPrice)),
            "Balance is wrong after second withdraw");
    });

    it("should not withdraw as expired if not expired", async () => {
        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gas: 3000000 }), 3000000);
    });

    it("should withdraw fees if owner", async () => {
        let web3GasPrice = await promisify(web3.eth.getGasPrice, []);

        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });
        let accountBalanceStep0 = await promisify(web3.eth.getBalance, [accounts[0]]);
        
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(10), "Fees has not been assigned");

        let withdrawTxInfo1 = await instance.withdrawFees({ from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await promisify(web3.eth.getBalance, [accounts[0]]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(10),
            "Balance is wrong after first withdraw");
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(0), "Fees has not been cleared");
    });

    it("should not withdraw fees from no owner", async () => {
        await instance.deposit(hash1, 100, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.withdrawFees({ from: accounts[1], gas: 3000000 }), 3000000);
    });
})
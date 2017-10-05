"use strict";

const expectedExceptionPromise = require("../../helpers/test/expectedExceptionPromise.js");
const Promise = require("bluebird");
const Remittance = artifacts.require("./Remittance.sol");

Promise.promisifyAll(web3.eth);

contract('Remittance', accounts => {
    const getGasCost = (txInfo, gasPrice) => gasPrice.mul(txInfo.receipt.cumulativeGasUsed);
    const account1Hash = web3.sha3(accounts[1], {encoding: 'hex'});
    const pswHash = web3.sha3("test");

    let instance;

    beforeEach(async () => instance = await Remittance.new());

    it("should have set deployer as owner", async () => {
        let owner = await instance.owner.call({ from: accounts[0] });
        assert.equal(owner, accounts[0], "Owner is wrong");
    });

    it("should deposit new founds", async () => {
        let depositTx = await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });
        let depositBlock = await web3.eth.getBlockAsync(depositTx.receipt.blockNumber);
        let blockTimestamp = depositBlock.timestamp;

        assert.deepEqual(await instance.deposits.call(pswHash, { from: accounts[0] }),
            [accounts[0],                               //author
             new web3.BigNumber(990 /* 1000 - 1% */),   //balance
             account1Hash,                              //receiverHash
             new web3.BigNumber(blockTimestamp + 100)], //endDate
            "Didn't create deposit");
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(10), "Fees has not been deposited");
    });

    it("should not deposit if paused", async () => {
        await instance.switchPause({ from: accounts[0] });
        await expectedExceptionPromise(() =>
            instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000);
    });
    
    it("should not deposit if duration is over max limit", async () => {
        await expectedExceptionPromise(() =>
            instance.deposit(pswHash, 5184000 /*60 days*/, account1Hash, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000)
    });
    
    it("should not deposit if already deposited", async () => {
        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });
        await expectedExceptionPromise(() =>
            instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 2000, gas: 3000000 }), 3000000);
    });

    it("should be paused from owner", async () => {
        await instance.switchPause({ from: accounts[0] });
        
        assert.isTrue(await instance.isPaused.call({ from: accounts[0] }), "Has not been paused")

        await instance.switchPause({ from: accounts[0] });
        
        assert.isFalse(await instance.isPaused.call({ from: accounts[0] }), "Has not been unpaused")
    });

    it("should not be paused from not owner", async () => {
        await expectedExceptionPromise(() =>
            instance.switchPause({ from: accounts[1], gas: 3000000 }), 3000000);
    });

    it("should withdraw deposit with passwords", async () => {
        let web3GasPrice = await web3.eth.getGasPriceAsync();
        let accountBalanceStep0 = await web3.eth.getBalanceAsync(accounts[1]);

        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });

        let withdrawTxInfo1 = await instance.withdrawDeposit("te", "st", { from: accounts[1], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await web3.eth.getBalanceAsync(accounts[1]);

        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(990),
            "Balance is wrong after first withdraw");

        await expectedExceptionPromise(() =>
            instance.withdrawDeposit("te", "st", { from: accounts[1], gasPrice: web3GasPrice, gas: 3000000 }), 3000000);
    });

    it("should not withdraw with passwords if not receiver", async () => {
        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.withdrawDeposit("te", "st", { from: accounts[0], gas: 3000000 }), 3000000);
    });

    it("should not withdraw with passwords if expired", async () => {
        await instance.deposit(pswHash, 1, account1Hash, { from: accounts[0], value: 1000 });
        await Promise.delay(2000);

        await expectedExceptionPromise(() =>
            instance.withdrawDeposit("te", "st", { from: accounts[1], gas: 3000000 }), 3000000);
    });

    it("should withdraw deposit as expired if author", async () => {
        let web3GasPrice = await web3.eth.getGasPriceAsync();

        await instance.deposit(pswHash, 1, account1Hash, { from: accounts[0], value: 1000 });
        let accountBalanceStep0 = await web3.eth.getBalanceAsync(accounts[0]);
        await Promise.delay(2000);
        
        let withdrawTxInfo1 = await instance.withdrawExpiredDeposit(pswHash, { from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await web3.eth.getBalanceAsync(accounts[0]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(990),
            "Balance is wrong after first withdraw");

        let withdrawTxInfo2 = await instance.withdrawExpiredDeposit(pswHash, { from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep2 = await web3.eth.getBalanceAsync(accounts[0]);
        
        assert.deepEqual(accountBalanceStep2,
            accountBalanceStep1.sub(getGasCost(withdrawTxInfo2, web3GasPrice)),
            "Balance is wrong after second withdraw");
    });

    it("should not withdraw as expired if not expired", async () => {
        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.withdrawExpiredDeposit(pswHash, { from: accounts[0], gas: 3000000 }), 3000000);
    });

    it("should withdraw fees if owner", async () => {
        let web3GasPrice = await web3.eth.getGasPriceAsync();

        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });
        let accountBalanceStep0 = await web3.eth.getBalanceAsync(accounts[0]);
        
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(10), "Fees has not been assigned");

        let withdrawTxInfo1 = await instance.withdrawFees({ from: accounts[0], gasPrice: web3GasPrice });
        let accountBalanceStep1 = await web3.eth.getBalanceAsync(accounts[0]);
        
        assert.deepEqual(accountBalanceStep1,
            accountBalanceStep0.sub(getGasCost(withdrawTxInfo1, web3GasPrice)).add(10),
            "Balance is wrong after first withdraw");
        assert.deepEqual(await instance.depositedFees.call({ from: accounts[0] }),
            new web3.BigNumber(0), "Fees has not been cleared");
    });

    it("should not withdraw fees from no owner", async () => {
        await instance.deposit(pswHash, 100, account1Hash, { from: accounts[0], value: 1000 });

        await expectedExceptionPromise(() =>
            instance.withdrawFees({ from: accounts[1], gas: 3000000 }), 3000000);
    });
})
const expectedExceptionPromise = require("../../helpers/test/expected_exception_testRPC_and_geth.js");
var Remittance = artifacts.require("./Remittance.sol");
var keccak256 = obj => "0x" + require('js-sha3').keccak256(obj);

contract('Remittance', accounts => {
    const getGasCost = txInfo => web3.eth.gasPrice.mul(txInfo.receipt.cumulativeGasUsed);

    var remittance;

    beforeEach(() => Remittance.new()
        .then(_instance => remittance = _instance));

    it("Should set owner", () => {
        var instance = remittance;

        instance.owner.call({ from: accounts[0] })
            .then(result => assert.equal(result, accounts[0], "Owner is wrong"))
    });

    it("Should update change password hash", () => {
        var instance = remittance;
        var hash1 = keccak256("test");
        var hash2 = keccak256("test2");
        var deposit;

        instance.deposit(hash1, 12, { from: accounts[0], value: 1000 })
            .then(txInfo => instance.deposits.call(accounts[0], hash1, { from: accounts[0] }))
            .then(_deposit => {
                deposit = _deposit;
                return instance.changePswsHash(hash1, hash2, { from: accounts[0] });
            })
            .then(txInfo => instance.deposits.call(accounts[0], hash2, { from: accounts[0] }))
            .then(_deposit => {
                assert.deepEqual(_deposit, deposit, "Should be moved");
                return instance.deposits.call(accounts[0], hash1, { from: accounts[0] });
            })
            .then(_deposit => assert.deepEqual(_deposit,
                [new web3.BigNumber(0), new web3.BigNumber(0), new web3.BigNumber(0)],
                "Should set to 0 on prev hash"));
    });

    it("Should deposit new founds", () => {
        var instance = remittance;
        var hash1 = keccak256("test");
        var blockTimestamp;

        instance.deposit(hash1, 12, { from: accounts[0], value: 1000 })
            .then(txInfo => {
                var block = web3.eth.getBlock(txInfo.receipt.blockNumber);
                blockTimestamp = block.timestamp;

                return instance.deposits.call(accounts[0], hash1, { from: accounts[0] });
            })
            .then(_deposit => {
                assert.deepEqual(_deposit,
                    [new web3.BigNumber(990 /* 1000 - 1% */),
                     new web3.BigNumber(blockTimestamp),
                     new web3.BigNumber(blockTimestamp + 43200 /* +12h */)],
                    "Should set deposit");

                return instance.depositedFees.call({ from: accounts[0] });
            })
            .then(_fees => assert.deepEqual(_fees, new web3.BigNumber(10), "Should deposit fees"));
    });

    it("Should not deposit if killed", () => {
        var instance = remittance;
        var hash1 = keccak256("test");

        instance.kill({ from: accounts[0] })
            .then(txInfo => expectedExceptionPromise(() =>
                instance.deposit(hash1, 12, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000));
    });
    
    it("Should not deposit if duration is over max limit", () => {
        var instance = remittance;
        var hash1 = keccak256("test");

        expectedExceptionPromise(() =>
            instance.deposit(hash1, 1440 /*60 days*/, { from: accounts[0], value: 1000, gas: 3000000 }), 3000000)
    });
    
    it("Should not deposit if already deposited", () => {
        var instance = remittance;
        var hash1 = keccak256("test");

        instance.deposit(hash1, 12, { from: accounts[0], value: 1000 })
            .then(txInfo => expectedExceptionPromise(() =>
                instance.deposit(hash1, 12, { from: accounts[0], value: 2000, gas: 3000000 }), 3000000));
    });

    it("Should kill from owner", () => {
        var instance = remittance;

        instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return instance.kill({ from: accounts[0] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isTrue(result, "Should be killed"))
    });

    it("Should not kill from not owner", () => {
        var instance = remittance;

        instance.isKilled.call({ from: accounts[0] })
            .then(result => {
                assert.isFalse(result, "Should not be killed");
                return instance.kill({ from: accounts[1] });
            })
            .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
            .then(result => assert.isFalse(result, "Should not be killed"))
    });

    it("Should withdraw deposit with passwords", () => {
        var instance = remittance;
        var accountBalanceStep0 = web3.eth.getBalance(accounts[1]);
        var accountBalanceStep1;
        var accountBalanceStep2;
        var hash1 = keccak256("test");

        instance.deposit(hash1, 12, { from: accounts[0], value: 1000 })
            .then(txInfo => instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[1], gasPrice: web3.eth.gasPrice }))
            .then(txInfo => {
                accountBalanceStep1 = web3.eth.getBalance(accounts[1]);

                assert.deepEqual(accountBalanceStep1,
                    accountBalanceStep0.sub(getGasCost(txInfo)).add(990),
                    "Balance is wrong after first withdraw");

                return instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[1], gasPrice: web3.eth.gasPrice });
            })
            .then(txInfo => {
                accountBalanceStep2 = web3.eth.getBalance(accounts[1]);

                assert.deepEqual(accountBalanceStep2,
                    accountBalanceStep1.sub(getGasCost(txInfo)),
                    "Balance is wrong after second withdraw");
            })
    });

    it("Should not withdraw expired deposit with passwords", () => {
        var instance = remittance;
        var accountBalanceStep0 = web3.eth.getBalance(accounts[1]);
        var accountBalanceStep1;
        var hash1 = keccak256("test");

        instance.deposit(hash1, 0, { from: accounts[0], value: 1000 })
            .then(txInfo => expectedExceptionPromise(() =>
                instance.withdrawDeposit(accounts[0], "te", "st", { from: accounts[0], gas: 3000000 }), 3000000))
    });

    it("Should withdraw expired deposit if author", () => {
        var instance = remittance;
        var accountBalanceStep0;
        var accountBalanceStep1;
        var accountBalanceStep2;
        var hash1 = keccak256("test");

        instance.deposit(hash1, 0, { from: accounts[0], value: 1000 })
            .then(txInfo => {
                accountBalanceStep0 = web3.eth.getBalance(accounts[0]);

                return instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gasPrice: web3.eth.gasPrice });
            })
            .then(txInfo => {
                accountBalanceStep1 = web3.eth.getBalance(accounts[0]);

                assert.deepEqual(accountBalanceStep1,
                    accountBalanceStep0.sub(getGasCost(txInfo)).add(990),
                    "Balance is wrong after first withdraw");

                return instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gasPrice: web3.eth.gasPrice });
            })
            .then(txInfo => {
                accountBalanceStep2 = web3.eth.getBalance(accounts[0]);

                assert.deepEqual(accountBalanceStep2,
                    accountBalanceStep1.sub(getGasCost(txInfo)),
                    "Balance is wrong after second withdraw");
            })
    });

    //********* */

    it("Should withdraw fees from owner", () => {
        var instance = remittance;
        var accountBalanceStep0;
        var accountBalanceStep1;
        var accountBalanceStep2;
        var hash1 = keccak256("test");

        instance.deposit(hash1, 1, { from: accounts[0], value: 1000 })
            .then(txInfo => {
                accountBalanceStep0 = web3.eth.getBalance(accounts[0]);

                // return instance.depositedFees.call({ from: accounts[0] });
            })
            // .then(fees => {
            //     assert.deepEqual(fees, new web3.BigNumber(10), "Fees has not been assigned");

            //     return instance.withdrawFees({ from: accounts[0], gasPrice: web3.eth.gasPrice });
            // })
            // .then(txInfo => {
            //     accountBalanceStep1 = web3.eth.getBalance(accounts[0]);

            //     assert.deepEqual(accountBalanceStep1,
            //         accountBalanceStep0.sub(getGasCost(txInfo)).add(10),
            //         "Balance is wrong after first withdraw");

            //     return instance.depositedFees.call({ from: accounts[0] });
            // })
            // .then(fees => {
            //     assert.deepEqual(fees, new web3.BigNumber(0), "Fees has not been cleared");

            //     return instance.withdrawExpiredDeposit(hash1, { from: accounts[0], gasPrice: web3.eth.gasPrice });
            // })
            // .then(txInfo => {
            //     accountBalanceStep2 = web3.eth.getBalance(accounts[0]);

            //     assert.deepEqual(accountBalanceStep2,
            //         accountBalanceStep1.sub(getGasCost(txInfo)),
            //         "Balance is wrong after second withdraw");
            // })
    });

    // it("Should not withdraw fees from no owner", () => {
    //     var instance = remittance;

    //     instance.isKilled.call({ from: accounts[0] })
    //         .then(result => {
    //             assert.isFalse(result, "Should not be killed");
    //             return instance.kill({ from: accounts[1] });
    //         })
    //         .then(txInfo => instance.isKilled.call({ from: accounts[0] }))
    //         .then(result => assert.isFalse(result, "Should not be killed"))
    // });
})
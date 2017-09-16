var Remittance = artifacts.require("./Remittance.sol");
var keccak256 = obj => "0x" + require('js-sha3').keccak256(obj);

contract('Remittance', accounts => {
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
            .then(_deposit => assert.deepEqual(_deposit,
                [new web3.BigNumber(990 /* 1000 - 1% */),
                 new web3.BigNumber(blockTimestamp),
                 new web3.BigNumber(blockTimestamp + 43200 /* +12h */)],
                "Should set deposit"));
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
})
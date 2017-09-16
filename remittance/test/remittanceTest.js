var Remittance = artifacts.require("./Remittance.sol");
var keccak256 = obj => "0x" + require('js-sha3').keccak256(obj);

contract('Remittance', accounts => {
    var instance;

    beforeEach(() => Remittance.new()
        .then(_instance => instance = _instance));

    it("Should set owner", () =>
        instance.owner.call({ from: accounts[0] })
            .then(result => assert.equal(result, accounts[0], "Owner is wrong"))
    );

    it("Should update change password hash", () => {
        var hash1 = keccak256("test");
        var hash2 = keccak256("test2");
        var deposit;

        instance.deposit(hash1, 12 /*h*/, { from: accounts[0], value: 1000 })
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
            .then(_deposit => assert.deepEqual(_deposit, [new web3.BigNumber(0), new web3.BigNumber(0), new web3.BigNumber(0)],
                "Previous should be setted to 0"));
    });

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
})
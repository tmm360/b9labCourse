var Remittance = artifacts.require("./Remittance.sol");

contract('Remittance', accounts => {
    var instance;

    beforeEach(() => Remittance.new()
        .then(_instance => instance = _instance));

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
})
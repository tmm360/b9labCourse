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

    // //Using https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/helpers/expectThrow.js
    // it("Should not split if killed", () =>
    //     instance.kill({ from: accounts[0] })
    //         .then(async txInfo =>
    //             await expectThrow(instance.sendTransaction({ from: accounts[0], value: 1000 })))
    // );

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
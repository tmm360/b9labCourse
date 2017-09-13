pragma solidity ^0.4.15;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Splitter.sol";

contract SplitterTest {
    address bobAddress = 0xBeB2A06Eb48AcDd0e4C23B6740E04c495856fA08;
    address carolAddress = 0x79D5D78b75469d06f06ce56A69890eDe014112E9;

    function testDefaultAddresses() {
        Splitter splitter = new Splitter(bobAddress, carolAddress);

        Assert.equal(splitter.bobAddress(), bobAddress, "Bob address is wrong");
        Assert.equal(splitter.carolAddress(), carolAddress, "Carol address is wrong");
    }

    //*** How to test that owner is well setted?
    function testOwner() {
        Splitter splitter = new Splitter(bobAddress, carolAddress);

        Assert.equal(splitter.owner(), msg.sender, "Owner is wrong");
    }

    function testKill() {
        Splitter splitter = new Splitter(bobAddress, carolAddress);
        Assert.isFalse(splitter.isKilled(), "Should not be killed");

        splitter.kill();

        Assert.isTrue(splitter.isKilled(), "Should be killed");
    }

    //*** Receive with testrpc: "Error: VM Exception while processing transaction: invalid opcode"
    function testDefaultSplit() payable {
        Splitter splitter = new Splitter(bobAddress, carolAddress);

        splitter.transfer(1000);

        Assert.balanceEqual(bobAddress, 500, "Wrong balance for addr1");
        Assert.balanceEqual(carolAddress, 500, "Wrong balance for addr2");
    }

    //*** Receive with testrpc: "Error: VM Exception while processing transaction: invalid opcode"
    function testSplit() payable {
        Splitter splitter = new Splitter(bobAddress, carolAddress);
        address addr1 = 0x2836C2B0fBf18Bc8e889Ba4782d76fAFed5cfC13;
        address addr2 = 0xabCEbb26FFC6dF88b0D2E7F73f00f7883D1bfd5d;

        splitter.split.value(1000)(addr1, addr2);

        Assert.balanceEqual(addr1, 500, "Wrong balance for addr1");
        Assert.balanceEqual(addr2, 500, "Wrong balance for addr2");
    }

    //*** How to test that contract should throw exception if killed?
    function testKilledSplit() {
    }
}

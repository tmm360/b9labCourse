pragma solidity ^0.4.15;

contract Splitter {
    // Fields.
    address public bobAddress;
    address public carolAddress;

    // Events.
    event SimpleSplit(uint ammount);

    // Costructor.
    function Splitter(
        address _bobAddress,
        address _carolAddress
    ) {
        bobAddress = _bobAddress;
        carolAddress = _carolAddress;
    }

    // Functions.
    function getBobBalance() returns (uint balance) {
        return bobAddress.balance;
    }
    
    function getCarolBalance() returns (uint balance) {
        return carolAddress.balance;
    }

    //deafult
    function () payable {
        //handle case of odd msg.value
        uint bobValue = msg.value / 2;
        uint carolValue = msg.value - bobValue;

        bobAddress.transfer(bobValue);
        carolAddress.transfer(carolValue);
    }
}
pragma solidity ^0.4.15;

contract Splitter {
    // Fields.
    address public bobAddress;
    address public carolAddress;
    bool public isKilled;
    address public owner;

    // Events.
    event SplitEvent(
        address indexed sender,
        address indexed receiver1,
        address indexed receiver2,
        uint ammount);

    // Modifiers.
    modifier restricted() {
        if (msg.sender == owner)
            _;
    }

    // Costructor.
    function Splitter(
        address _bobAddress,
        address _carolAddress
    ) {
        bobAddress = _bobAddress;
        carolAddress = _carolAddress;

        owner = msg.sender;
    }

    // Functions.
    function kill() restricted {
        isKilled = true;
    }

    function split(address receiver1, address receiver2) payable {
        //requisites
        require(!isKilled);

        //handle case of odd msg.value (why handle 0.5 wei?)
        uint receiver1Value = msg.value / 2;
        uint receiver2Value = msg.value - receiver1Value;

        //events
        SplitEvent(
            msg.sender,
            receiver1,
            receiver2,
            msg.value);

        //split
        receiver1.transfer(receiver1Value);
        receiver2.transfer(receiver2Value);
    }

    //deafult
    function () payable {
        split(bobAddress, carolAddress);
    }
}
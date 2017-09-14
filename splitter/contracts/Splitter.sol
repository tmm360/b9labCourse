pragma solidity ^0.4.15;

contract Splitter {
    // Fields.
    address public bobAddress;
    address public carolAddress;

    mapping (address => uint) balances;
    bool public isKilled;
    address public owner;

    // Events.
    event KilledEvent();
    event SplitEvent(
        address indexed sender,
        address indexed receiver1,
        address indexed receiver2,
        uint ammount);
    event WithdrawEvent(
        address indexed addr,
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
    function getBalance(address addr) constant returns (uint balance) {
        return balances[addr];
    }

    function getTotalBalance() constant returns (uint balance) {
        return this.balance;
    }

    function kill() restricted {
        KilledEvent();
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
        balances[receiver1] += receiver1Value;
        balances[receiver2] += receiver2Value;
    }

    function withdraw() {
        //get
        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;

        //events
        WithdrawEvent(msg.sender, amount);

        //withdraw
        msg.sender.transfer(amount);
    }

    //deafult
    function () payable {
        split(bobAddress, carolAddress);
    }
}
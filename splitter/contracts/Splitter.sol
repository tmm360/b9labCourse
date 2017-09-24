pragma solidity ^0.4.15;

contract Splitter {
    // Fields.
    mapping (address => uint) public balances;
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
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Costructor.
    function Splitter()
    {
        owner = msg.sender;
    }

    // Functions.
    function kill()
        public
        onlyOwner
    {
        isKilled = true;

        KilledEvent();
    }

    function split(address receiver1, address receiver2)
        public
        payable
    {
        require(!isKilled);
        require(receiver1 != address(0));
        require(receiver2 != address(0));

        uint receiver1Value = msg.value / 2;
        uint receiver2Value = msg.value - receiver1Value;

        balances[receiver1] += receiver1Value;
        balances[receiver2] += receiver2Value;

        SplitEvent(msg.sender, receiver1, receiver2, msg.value);
    }

    function withdraw()
        public
    {
        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;

        msg.sender.transfer(amount);

        WithdrawEvent(msg.sender, amount);
    }
}
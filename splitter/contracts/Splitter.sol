pragma solidity ^0.4.15;

contract Splitter {
    // Fields.
    mapping (address => uint) public balances;
    bool public isPaused;
    address public owner;

    // Events.
    event SetPauseEvent(bool value);
    event SplitEvent(
        address indexed sender,
        address indexed receiver1,
        address indexed receiver2,
        uint ammount);
    event WithdrawEvent(
        address indexed addr,
        uint ammount);

    // Modifiers.
    modifier onlyIfRunning() {
        require(!isPaused);
        _;
    }

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
    function setPause(bool pause)
        public
        onlyOwner
        returns (bool success)
    {
        isPaused = pause;

        SetPauseEvent(pause);

        return true;
    }

    function split(address receiver1, address receiver2)
        public
        onlyIfRunning
        payable
        returns (bool success)
    {
        require(receiver1 != address(0));
        require(receiver2 != address(0));

        uint half = msg.value / 2;

        balances[receiver1] += half;
        balances[receiver2] += half;
        balances[msg.sender] += msg.value % 2;

        SplitEvent(msg.sender, receiver1, receiver2, msg.value);

        return true;
    }

    function withdraw()
        public
        returns (bool success)
    {
        uint amount = balances[msg.sender];
        require(amount > 0);
        balances[msg.sender] = 0;

        msg.sender.transfer(amount);

        WithdrawEvent(msg.sender, amount);

        return true;
    }
}
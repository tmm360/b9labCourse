pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Collect is Pausable {
    // Enums.
    enum States { active, cancelled, succeeded }

    // Fields.
    uint public ammount;
    address public author;
    mapping(address => uint) public contribs; //sender => ammount
    States public status;

    // Events.
    event LogCancell();

    // Modifiers.
    modifier onlyAuthor() { require(author == msg.sender); _; }
    modifier onlyIfActive() { require(status == States.active); _; }

    // Constructor.
    function Collect(address _author) {
        author = _author;
    }

    // Functions.
    function cancell()
        public
        onlyAuthor
        onlyIfActive
        whenNotPaused
        returns (bool success)
    {
        status = States.cancelled;
        LogCancell();
        return true;
    }
    
    function deposit()
        public
        whenNotPaused
        onlyIfActive
        payable
        returns (bool success)
    {
        //***** */
    }
}
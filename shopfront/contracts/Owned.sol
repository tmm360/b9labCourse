pragma solidity ^0.4.15;

contract Owned {
    // Fields.
    address public owner;

    // Modifiers.
    modifier fromOwner() {
        require(msg.sender == owner);
        _;
    }

    // Constructor.
    function Owned() {
        owner = msg.sender;
    }
}
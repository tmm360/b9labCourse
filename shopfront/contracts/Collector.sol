pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./Shopfront.sol";

contract Collector is Pausable {
    // Structs.
    struct Collect {
        uint ammount;
        address author;
        mapping(address => uint) contribs; //sender => ammount
        bool isCancelled;
        bool isSucceeded;
    }
    
    // Fields.
    mapping (bytes32 => Collect) collects;
    Shopfront shopfront;

    // Constructor.
    function Collector(address shopfrontAddress) {
        shopfront = Shopfront(shopfrontAddress);
    }

    // Modifiers.
    modifier onlyAuthor(bytes32 collectId) {
        require(collects[collectId].author == msg.sender);
        _;
    }

    modifier whenOpenCollect(bytes21 collectId) {
        Collect collect = collects[collectId];
        require(collect.author != address(0));
        require(!collect.isCancelled);
        require(!collect.isSucceeded);
        _;
    }

    // Functions.
    function cancelCollect(bytes id)
        public
        whenNotPaused()
        whenOpenCollect(id)
        onlyAuthor(id)
        returns (bool succeeded)
    {
        //****** */
    }

    function deposit(bytes32 id)
        public
        whenNotPaused()
        whenOpenCollect(id)
        payable
        returns (bool succeeded)
    {
        //***** */
    }

    function startCollect()
        public
        whenNotPaused()
        payable
        returns (bytes32 id)
    {
        id = keccak256(msg.sender, block.number);
        require(collects[id].author == address(0));
        
        collects[id] = Collect({
            author: msg.sender
        });
        if (msg.value > 0)
            deposit(id);

        return id;
    }

    function tryBuyProduct(bytes32 id)
        public
        onlyAuthor(id)
        whenNotPaused()
        whenOpenCollect(id)
        returns (bool succeeded)
    {
        //***** */
    }

    function withdrawDeposit(bytes32 id)
        public
        whenNotPaused()
        returns (bool succeeded)
    {
        /***** */
    }
}
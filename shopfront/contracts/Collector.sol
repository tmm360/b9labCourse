pragma solidity ^0.4.15;

import "./Owned.sol";
import "./Shopfront.sol";

contract Collector is Owned {
    // Structs.
    struct Collect {
        address author;
        bytes32 productId;
        uint quantity;
        address returnAddress;
    }
    
    // Fields.
    mapping (bytes32 => Collect) collects;

    // Modifiers.
    modifier fromAuthor(bytes32 collectId) {
        require(collects[collectId].author == msg.sender);
        _;
    }

    // Functions.
    function startCollect(bytes32 productId, uint quantity, address returnAddress)
        public payable returns(bytes32 id)
    {
        require(products[id].seller != address(0));
        require(products[id].stock <= quantity);
        uint totalPrice = products[id].price * quantity;
        require(returnAddress != address(0));

        id = keccak256(msg.sender, productId, block.number);

    }

    function tryBoughtProduct(bytes32 collectId)
        public fromAuthor(collectId)
    {

    }
}
pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./Collect.sol";
import "./Shopfront.sol";

contract CollectHub is Pausable {
    // Fields.
    mapping (bytes32 => Collect) collects;
    Shopfront shopfront;

    // Constructor.
    function CollectHub(address shopfrontAddress) {
        shopfront = Shopfront(shopfrontAddress);
    }

    // Functions.
    // function startCollect()
    //     public
    //     whenNotPaused()
    //     payable
    //     returns (bytes32 id)
    // {
    //     id = keccak256(msg.sender, block.number);
    //     require(collects[id].author == address(0));
        
    //     collects[id] = Collect({
    //         author: msg.sender
    //     });
    //     if (msg.value > 0)
    //         deposit(id);

    //     return id;
    // }

    // function tryBuyProduct(bytes32 id)
    //     public
    //     onlyAuthor(id)
    //     whenNotPaused()
    //     whenOpenCollect(id)
    //     returns (bool succeeded)
    // {
    //     //***** */
    // }

    // function withdrawDeposit(bytes32 id)
    //     public
    //     whenNotPaused()
    //     returns (bool succeeded)
    // {
    //     /***** */
    // }
}
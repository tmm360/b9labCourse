pragma solidity ^0.4.13;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./MetaCoinERC20.sol";

contract ProductHolder is Pausable {
    // Structs.
    struct Product {
        bool acceptMetaCoin;
        uint price;
        address seller;
        uint stock;
    }

    // Fields.
    mapping (bytes32 => Product) public products; //id -> product

    // Events.
    event LogAddedProduct(address indexed seller, bytes32 indexed id, uint indexed internalId, bool acceptMetaCoin, uint price, uint stock);
    event LogProductRemoved(address indexed seller, bytes32 indexed id);
    event LogUpdatedStock(address indexed seller, bytes32 indexed id, uint stock);

    // Modifiers.
    modifier onlyIfAvailable(bytes32 id) {
        require(products[id].stock >= 1); //check availability
        _;
    }
    modifier onlySeller(bytes32 id) { require(products[id].seller == msg.sender); _; }

    // Functions.
    function addProduct(bool acceptMetaCoin, uint internalId, uint price, uint stock)
        public
        whenNotPaused
        returns (bytes32 id)
    {
        id = keccak256(msg.sender, internalId);
        require(products[id].seller == address(0)); //check for empty product

        products[id] = Product({
            acceptMetaCoin : acceptMetaCoin,
            price : price,
            seller : msg.sender,
            stock : stock
        });

        LogAddedProduct(msg.sender, id, internalId, acceptMetaCoin, price, stock);
        return id;
    }

    function getProductPriceInWei(bytes32 id)
        public
        constant
        returns (uint price)
    {
        return products[id].price;
    }

    function getProductStock(bytes32 id)
        public
        constant
        returns (uint stock)
    {
        return products[id].stock;
    }

    function removeProduct(bytes32 id)
        public
        whenNotPaused
        onlySeller(id)
        returns (bool success)
    {
        delete products[id];
        LogProductRemoved(msg.sender, id);
        return true;
    }

    function updateStock(bytes32 id, uint stock)
        public
        whenNotPaused
        onlySeller(id)
        returns (bool success)
    {
        require(products[id].stock != stock);

        products[id].stock = stock;
        LogUpdatedStock(msg.sender, id, stock);
        return true;
    }
}
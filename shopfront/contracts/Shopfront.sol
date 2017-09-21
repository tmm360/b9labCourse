pragma solidity ^0.4.15;

import "./Owned.sol";

contract Shopfront is Owned {
    // Structs.
    struct Product {
        string name;
        uint price;
        address seller;
        uint stock;
    }

    // Consts.
    uint THOUSANDTHS_FEES_RATE = 50; //5%

    // Fields.
    mapping (bytes32 => Product) public products;
    mapping (address => uint) public revenues;
    uint public totalFees;

    // Events.
    event AddedProductEvent(address indexed seller, bytes32 id);
    event ProductBoughtEvent(address buyer, bytes32 id, uint quantity);
    event UpdatedStockEvent(address indexed seller, bytes32 id, uint stock);

    // Modifiers.
    modifier fromSeller(bytes32 productId) {
        require(products[productId].seller == msg.sender);
        _;
    }

    // Functions.
    function addProduct(string name, uint price, uint stock)
        public returns (bytes32 id)
    {
        id = keccak256(msg.sender, name);
        require(products[id].seller == address(0)); //check for empty product

        products[id] = Product({
            name : name,
            price : price,
            seller : msg.sender,
            stock : stock
        });
        AddedProductEvent(msg.sender, id);
        return id;
    }

    function buyProduct(bytes32 id, uint quantity, address returnAddress)
        public payable
    {
        require(products[id].seller != address(0));
        require(products[id].stock <= quantity);
        uint totalPrice = products[id].price * quantity;
        require(totalPrice <= msg.value);
        require(returnAddress != address(0));

        products[id].stock -= quantity;

        uint fees = totalPrice * THOUSANDTHS_FEES_RATE / 1000;
        totalFees += fees;
        revenues[products[id].seller] += totalPrice - fees;

        ProductBoughtEvent(msg.sender, id, quantity);

        if (msg.value > totalPrice)
            returnAddress.transfer(msg.value - totalPrice);
    }

    function removeProduct(bytes32 id)
        public fromSeller(id)
    {
        delete products[id];
    }

    function updateStock(bytes32 id, uint stock)
        public fromSeller(id)
    {
        products[id].stock = stock;
        UpdatedStockEvent(msg.sender, id, stock);
    }

    function withdrawFees()
        public fromOwner()
    {
        uint fees = totalFees;
        totalFees = 0;
        owner.transfer(fees);
    }

    function withdrawSellerRevenue()
        public
    {
        uint revenue = revenues[msg.sender];
        revenues[msg.sender] = 0;
        msg.sender.transfer(revenue);
    }
}
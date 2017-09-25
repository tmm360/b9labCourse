pragma solidity ^0.4.15;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Shopfront is Pausable {
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
    modifier onlySeller(bytes32 productId) {
        require(products[productId].seller == msg.sender);
        _;
    }

    // Functions.
    function addProduct(string name, uint price, uint stock)
        public
        whenNotPaused()
        returns (bytes32 id)
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
        public
        whenNotPaused()
        payable
        returns (bool succeeded)
    {
        Product product = products[id];
        require(product.seller != address(0));
        require(product.stock <= quantity);
        uint totalPrice = product.price * quantity;
        require(totalPrice <= msg.value);
        require(returnAddress != address(0));

        product.stock -= quantity;

        uint fees = totalPrice * THOUSANDTHS_FEES_RATE / 1000;
        totalFees += fees;
        revenues[product.seller] += totalPrice - fees;

        ProductBoughtEvent(msg.sender, id, quantity);

        if (msg.value > totalPrice)
            returnAddress.transfer(msg.value - totalPrice);
        
        return true;
    }

    function removeProduct(bytes32 id)
        public
        whenNotPaused()
        onlySeller(id)
        returns (bool succeeded)
    {
        delete products[id];

        return true;
    }

    function updateStock(bytes32 id, uint stock)
        public
        whenNotPaused()
        onlySeller(id)
        returns (bool succeeded)
    {
        products[id].stock = stock;
        UpdatedStockEvent(msg.sender, id, stock);

        return true;
    }

    function withdrawFees()
        public
        whenNotPaused()
        onlyOwner()
        returns (bool succeeded)
    {
        uint fees = totalFees;
        totalFees = 0;
        owner.transfer(fees);

        return true;
    }

    function withdrawSellerRevenue()
        public
        whenNotPaused()
        returns (bool succeeded)
    {
        uint revenue = revenues[msg.sender];
        revenues[msg.sender] = 0;
        msg.sender.transfer(revenue);

        return true;
    }
}
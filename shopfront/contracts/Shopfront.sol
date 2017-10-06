pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Shopfront is Pausable {
    // Structs.
    struct Product {
        uint internalId;
        uint price;
        address seller;
        uint stock;
    }

    // Consts.
    uint constant THOUSANDTHS_FEES_RATE = 50; //5%

    // Fields.
    mapping (bytes32 => Product) public products; //id -> product
    mapping (address => uint) public revenues; //seller -> ammount
    uint public totalFees;

    // Events.
    event LogAddedProduct(address indexed seller, bytes32 indexed id);
    event LogProductBought(address indexed buyer, bytes32 indexed id);
    event LogProductRemoved(address indexed seller, bytes32 indexed id);
    event LogUpdatedStock(address indexed seller, bytes32 indexed id, uint stock);
    event LogWithdrawFees(uint ammount);
    event LogWithdrawSellerRevenue(address indexed seller, uint ammount);

    // Modifiers.
    modifier onlySeller(bytes32 id) { require(products[id].seller == msg.sender); _; }

    // Functions.
    function addProduct(uint internalId, uint price, uint stock)
        public
        whenNotPaused
        returns (bytes32 id)
    {
        id = keccak256(msg.sender, internalId);
        require(products[id].seller == address(0)); //check for empty product

        products[id] = Product({
            internalId : internalId,
            price : price,
            seller : msg.sender,
            stock : stock
        });

        LogAddedProduct(msg.sender, id);
        return id;
    }

    function buyProduct(bytes32 id, address untrustedReturnAddress)
        public
        whenNotPaused
        payable
        returns (bool success)
    {
        Product storage product = products[id];
        require(product.seller != address(0));  //check existence
        require(product.stock >= 1);            //check availability
        require(product.price <= msg.value);
        require(untrustedReturnAddress != address(0));

        uint fees = product.price * THOUSANDTHS_FEES_RATE / 1000;

        product.stock--;
        totalFees += fees;
        revenues[product.seller] += product.price - fees;

        LogProductBought(msg.sender, id);

        if (msg.value > product.price)
            untrustedReturnAddress.transfer(msg.value - product.price);
        
        return true;
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

    function withdrawFees()
        public
        whenNotPaused
        onlyOwner
        returns (bool success)
    {
        require(totalFees > 0);

        uint fees = totalFees;
        totalFees = 0;
        owner.transfer(fees);

        LogWithdrawFees(fees);
        return true;
    }

    function withdrawSellerRevenue()
        public
        whenNotPaused
        returns (bool success)
    {
        require(revenues[msg.sender] > 0);

        uint revenue = revenues[msg.sender];
        revenues[msg.sender] = 0;
        msg.sender.transfer(revenue);

        LogWithdrawSellerRevenue(msg.sender, revenue);
        return true;
    }
}
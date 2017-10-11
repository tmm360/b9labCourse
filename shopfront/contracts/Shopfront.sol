pragma solidity ^0.4.15;

import "../installed_contracts/oraclize/contracts/usingOraclize.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./MetaCoinERC20.sol";

contract Shopfront is Pausable, usingOraclize {
    // Enums.
    enum CoinTypes { Ether, MetaCoin, USD }

    // Structs.
    struct CoinInfo {
        uint8 decimals;
        uint value;
    }
    struct Product {
        bool acceptMetaCoin;
        uint internalId; //used for search product info on seller's db
        uint price;
        address seller;
        uint stock;
    }

    // Consts.
    uint constant THOUSANDTHS_FEES_RATE = 50; // 5%

    // Fields.
    mapping (bytes32 => CoinInfo) coinInfo; // hash(coinType) -> coin info
    mapping (bytes32 => Product) public products; //id -> product
    mapping (bytes32 => mapping (address => uint)) public revenues; // hash(coinType) -> seller -> ammount
    mapping (bytes32 => uint) public totalFees; // hash(coinType) -> fees
    mapping (bytes32=>bool) validOraclizeIds;

    MetaCoinERC20 trustedMetaCoinContract;

    // Events.
    event LogAddedProduct(address indexed seller, bytes32 indexed id);
    event LogNewOraclizeQuery(string description);
    event LogProductBought(address indexed buyer, address indexed receiver, bytes32 indexed id, CoinTypes coinType);
    event LogProductRemoved(address indexed seller, bytes32 indexed id);
    event LogUpdateCoinValue(CoinTypes indexed coinType, uint8 decimals, uint value);
    event LogUpdatedStock(address indexed seller, bytes32 indexed id, uint stock);
    event LogWithdrawFees(uint ammount, CoinTypes coinType);
    event LogWithdrawSellerRevenue(address indexed seller, CoinTypes coinType, uint ammount);

    // Modifiers.
    modifier onlyIfAvailable(bytes32 id) {
        require(products[id].seller != address(0)); //check existence
        require(products[id].stock >= 1);           //check availability
        _;
    }
    modifier onlyOraclize() { require(oraclize_cbAddress() == msg.sender); _; }
    modifier onlySeller(bytes32 id) { require(products[id].seller == msg.sender); _; }

    // Constructor.
    function Shopfront(address metaCoinAddress) {
        trustedMetaCoinContract = MetaCoinERC20(metaCoinAddress);

        // Init coin values.
        coinInfo[keccak256(CoinTypes.Ether)] = CoinInfo({
            decimals : 18,
            value : 1 // 1 ether = 1 ether
        });
        coinInfo[keccak256(CoinTypes.MetaCoin)] = CoinInfo({
            decimals : 18,
            value : 100 // 100 MetaCoin = 1 ether
        });
    }

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
            internalId : internalId,
            price : price,
            seller : msg.sender,
            stock : stock
        });

        LogAddedProduct(msg.sender, id);
        return id;
    }

    function buyProductWithEther(bytes32 id, address untrustedReturnAddress, address receiver)
        public
        onlyIfAvailable(id)
        whenNotPaused
        payable
        returns (bool success)
    {
        require(untrustedReturnAddress != address(0));
        uint price = products[id].price;
        require(msg.value >= price);

        processPurchase(id, CoinTypes.Ether, receiver);

        if (msg.value > price)
            untrustedReturnAddress.transfer(msg.value - price);
        
        return true;
    }

    function buyProductWithMetaCoin(bytes32 id, address receiver)
        public
        onlyIfAvailable(id)
        whenNotPaused
        returns (bool succeess)
    {
        require(products[id].acceptMetaCoin);

        // Don't need to check token availability, because if "ERC20 allowance < price" transfer fails.
        trustedMetaCoinContract.transferFrom(msg.sender, this,
            convertValueFromWei(products[id].price, keccak256(CoinTypes.MetaCoin)));

        processPurchase(id, CoinTypes.MetaCoin, receiver);

        return true;
    }

    function getProductPriceInWei(bytes32 id)
        public
        constant
        returns (uint price)
    {
        return products[id].price;
    }

    function getProductPriceInMetaCoin(bytes32 id)
        public
        constant
        returns (uint price)
    {
        return convertValueFromWei(products[id].price, keccak256(CoinTypes.MetaCoin));
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

    function updateMetaCoinValue(uint value)
        public
        whenNotPaused
        onlyOwner
        returns (bool success)
    {
        bytes32 coinHash = keccak256(CoinTypes.MetaCoin);
        uint currentValue = coinInfo[coinHash].value;
        require(currentValue != value);

        coinInfo[coinHash].value = value;
        LogUpdateCoinValue(CoinTypes.MetaCoin, 18, value);
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

    function updateUSDPrice()
        public
        onlyOwner
        payable
        returns (bool success)
    {
        if (oraclize_getPrice("URL") > this.balance) {
            LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            bytes32 queryId =
                oraclize_query("URL", "json(https://api.coinmarketcap.com/v1/ticker/ethereum/).price_usd");
            validOraclizeIds[queryId] = true;
        }
        return true;
    }

    function withdrawEtherFees()
        public
        whenNotPaused
        onlyOwner
        returns (bool success)
    {
        bytes32 coinHash = keccak256(CoinTypes.Ether);
        require(totalFees[coinHash] > 0);

        uint fees = totalFees[coinHash];
        totalFees[coinHash] = 0;
        owner.transfer(fees);

        LogWithdrawFees(fees, CoinTypes.Ether);
        return true;
    }

    function withdrawMetaCoinFees()
        public
        whenNotPaused
        onlyOwner
        returns (bool success)
    {
        bytes32 coinHash = keccak256(CoinTypes.MetaCoin);
        require(totalFees[coinHash] > 0);

        uint fees = totalFees[coinHash];
        totalFees[coinHash] = 0;
        trustedMetaCoinContract.transfer(owner, fees);

        LogWithdrawFees(fees, CoinTypes.MetaCoin);
        return true;
    }

    function withdrawSellerEtherRevenue()
        public
        whenNotPaused
        returns (bool success)
    {
        bytes32 coinHash = keccak256(CoinTypes.Ether);
        require(revenues[coinHash][msg.sender] > 0);

        uint revenue = revenues[coinHash][msg.sender];
        revenues[coinHash][msg.sender] = 0;
        msg.sender.transfer(revenue);

        LogWithdrawSellerRevenue(msg.sender, CoinTypes.Ether, revenue);
        return true;
    }

    function withdrawSellerMetaCoinRevenue()
        public
        whenNotPaused
        returns (bool success)
    {
        bytes32 coinHash = keccak256(CoinTypes.MetaCoin);
        require(revenues[coinHash][msg.sender] > 0);

        uint revenue = revenues[coinHash][msg.sender];
        revenues[coinHash][msg.sender] = 0;
        trustedMetaCoinContract.transfer(msg.sender, revenue);

        LogWithdrawSellerRevenue(msg.sender, CoinTypes.MetaCoin, revenue);
        return true;
    }
    
    function __callback(bytes32 myid, string result)
        public
        onlyOraclize
    {
        require(validOraclizeIds[myid]);

        // Update USD value
        bytes32 coinHash = keccak256(CoinTypes.USD);
        CoinInfo storage coin = coinInfo[coinHash];
        uint currentValue = coin.value;

        var (value, decimals) = stringToFloat(result);
        if (currentValue != value) {
            coin.decimals = uint8(decimals);
            coin.value = value;
            LogUpdateCoinValue(CoinTypes.MetaCoin, uint8(decimals), value);
        }

        delete validOraclizeIds[myid];
    }

    // Helpers.
    function convertValueFromWei(uint value, bytes32 destCoinHash)
        private
        constant
        returns (uint destValue)
    {
        uint destCoinValue = coinInfo[destCoinHash].value;
        uint8 destCoinDecimals = coinInfo[destCoinHash].decimals;
        if (destCoinDecimals >= 18 /*ether decimals*/) {
            return value * destCoinValue * (10 ** uint(destCoinDecimals - 18));
        } else {
            return value * destCoinValue / (10 ** uint(18 - destCoinDecimals));
        }
    }

    function processPurchase(bytes32 id, CoinTypes coinType, address receiver)
        private
        onlyIfAvailable(id)
        whenNotPaused
        returns (bool success)
    {
        bytes32 coinHash = keccak256(coinType);
        Product storage product = products[id];

        if (receiver == address(0))
            receiver = msg.sender;
        uint price = convertValueFromWei(products[id].price, coinHash);
        uint fees = price * THOUSANDTHS_FEES_RATE / 1000;

        product.stock--;
        totalFees[coinHash] += fees;
        revenues[coinHash][product.seller] += price - fees;
        LogProductBought(msg.sender, receiver, id, coinType);

        return true;
    }

    function stringToFloat(string s)
        private
        constant
        returns (uint value, uint decimals)
    {
        bytes memory b = bytes(s);
        uint i;
        bool countingDecimals = false;
        value = 0;
        decimals = 0;
        for (i = 0; i < b.length; i++) {
            uint c = uint(b[i]);
            if (c == 46)
                countingDecimals = true;
            else if (c >= 48 && c <= 57) {
                value = value * 10 + (c - 48);
                if (countingDecimals)
                    decimals++;
            }
        }
    }
}
pragma solidity ^0.4.13;

import "../installed_contracts/oraclize/contracts/usingOraclize.sol";
import "../node_modules/zeppelin-solidity/contracts/payment/PullPayment.sol";
import "./MetaCoinERC20.sol";
import "./ProductHolder.sol";

contract Shopfront is ProductHolder, PullPayment, usingOraclize {
    // Enums.
    enum CoinTypes { Ether, MetaCoin, USD }

    // Structs.
    struct CoinInfo {
        uint8 decimals;
        uint value;
    }

    // Consts.
    uint8 constant ETHER_DECIMALS = 18;
    uint8 constant METACOIN_DECIMALS = 18;
    uint constant THOUSANDTHS_FEES_RATE = 50; // 5%

    // Fields.
    mapping (uint => CoinInfo) public coinInfo; // uint(coinType) -> coin info

    MetaCoinERC20 trustedMetaCoinContract;
    mapping (bytes32=>bool) validOraclizeIds;

    // Events.
    event LogNewOraclizeQuery(bytes32 indexed queryId, uint msgValue);
    event LogProductBought(address indexed buyer, address indexed receiver, bytes32 indexed id, CoinTypes coinType);
    event LogUpdateCoinValue(CoinTypes indexed coinType, uint8 decimals, uint value);

    // Modifiers.
    modifier onlyOraclize() { require(oraclize_cbAddress() == msg.sender); _; }

    // Constructor.
    function Shopfront(address metaCoinAddress) {
        require(metaCoinAddress != address(0));
        trustedMetaCoinContract = MetaCoinERC20(metaCoinAddress);

        // Init coin values.
        coinInfo[uint(CoinTypes.Ether)] = CoinInfo({
            decimals : ETHER_DECIMALS,
            value : 1 // 1 ether = 1 ether
        });
        coinInfo[uint(CoinTypes.MetaCoin)] = CoinInfo({
            decimals : METACOIN_DECIMALS,
            value : 100 // 100 MetaCoin = 1 ether
        });
    }

    // Functions.
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

        var (ownerRevenue, sellerRevenue) = processPurchase(id, CoinTypes.Ether, receiver);
        asyncSend(owner, ownerRevenue);
        asyncSend(products[id].seller, sellerRevenue);

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

        var (ownerRevenue, sellerRevenue) = processPurchase(id, CoinTypes.MetaCoin, receiver);

        // Don't need to check token availability, because if "ERC20 allowance < price" transfer fails.
        trustedMetaCoinContract.transferFrom(msg.sender, owner, ownerRevenue);
        trustedMetaCoinContract.transferFrom(msg.sender, products[id].seller, sellerRevenue);

        return true;
    }

    function getProductPriceInMetaCoin(bytes32 id)
        public
        constant
        returns (uint price)
    {
        return convertValueFromWei(products[id].price, CoinTypes.MetaCoin);
    }

    function updateMetaCoinValue(uint value)
        public
        whenNotPaused
        onlyOwner
        returns (bool success)
    {
        uint currentValue = coinInfo[uint(CoinTypes.MetaCoin)].value;
        require(currentValue != value);

        coinInfo[uint(CoinTypes.MetaCoin)].value = value;
        LogUpdateCoinValue(CoinTypes.MetaCoin, METACOIN_DECIMALS, value);
        return true;
    }

    function updateUSDPrice()
        public
        onlyOwner
        payable
        returns (bool success)
    {
        bytes32 queryId =
            oraclize_query("URL", "json(https://api.coinmarketcap.com/v1/ticker/ethereum/).0.price_usd");
        LogNewOraclizeQuery(queryId, msg.value);
        validOraclizeIds[queryId] = true;
        
        return true;
    }
    
    function __callback(bytes32 myid, string result)
        public
        onlyOraclize
    {
        require(validOraclizeIds[myid]);

        // Update USD value
        CoinInfo storage coin = coinInfo[uint(CoinTypes.USD)];

        coin.decimals = ETHER_DECIMALS; //arbitrary cast for simplify maths
        coin.value = parseInt(result, ETHER_DECIMALS);
        LogUpdateCoinValue(CoinTypes.USD, coin.decimals, coin.value);

        delete validOraclizeIds[myid];
    }

    // Helpers.
    function convertValueFromWei(uint value, CoinTypes destCoin)
        public
        constant
        returns (uint destValue)
    {
        uint destCoinValue = coinInfo[uint(destCoin)].value;
        uint8 destCoinDecimals = coinInfo[uint(destCoin)].decimals;
        if (destCoinDecimals >= ETHER_DECIMALS) {
            return value * destCoinValue * (10 ** uint(destCoinDecimals - ETHER_DECIMALS));
        } else {
            return value * destCoinValue / (10 ** uint(ETHER_DECIMALS - destCoinDecimals));
        }
    }

    function processPurchase(bytes32 id, CoinTypes coinType, address receiver)
        private
        onlyIfAvailable(id)
        whenNotPaused
        returns (uint ownerRevenue, uint sellerRevenue)
    {
        Product storage product = products[id];

        if (receiver == address(0))
            receiver = msg.sender;
        uint price = convertValueFromWei(products[id].price, coinType);
        uint fees = price * THOUSANDTHS_FEES_RATE / 1000;

        product.stock--;
        LogProductBought(msg.sender, receiver, id, coinType);

        return (fees, price - fees);
    }
}
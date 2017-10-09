pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./Shopfront.sol";

contract Collect is Pausable {
    // Enums.
    enum States { active, cancelled, succeeded }

    // Fields.
    uint public ammount;
    address public author;
    mapping(address => uint) public contribs; //sender => ammount
    address public receiver;
    States public status;

    Shopfront shopfront;

    // Events.
    event LogBuyProduct(bytes32 indexed productId);
    event LogCancell();
    event LogDeposit(address indexed sender, uint versed);
    event LogWithdrawCancelled(address indexed sender, uint contrib);

    // Modifiers.
    modifier onlyAuthor() { require(author == msg.sender); _; }
    modifier onlyIfActive() { require(status == States.active); _; }

    // Constructor.
    function Collect(address _author, address _receiver, address shopfrontAddress) {
        require(_author != address(0));
        require(_receiver != address(0));

        author = _author;
        receiver = _receiver;
        shopfront = Shopfront(shopfrontAddress);
    }

    // Functions.
    function buyProduct(bytes32 productId)
        public
        onlyAuthor
        onlyIfActive
        whenNotPaused
        returns (bool success)
    {
        require(shopfront.getProductPriceInWei(productId) <= ammount);
        require(shopfront.getProductStock(productId) >= 1);

        shopfront.buyProductWithEther.value(ammount)(productId, author, receiver);
        LogBuyProduct(productId);

        status = States.succeeded;
        return true;
    }

    function cancell()
        public
        onlyAuthor
        onlyIfActive
        whenNotPaused
        returns (bool success)
    {
        status = States.cancelled;
        LogCancell();
        return true;
    }
    
    function deposit()
        public
        onlyIfActive
        whenNotPaused
        payable
        returns (bool success)
    {
        require(msg.value > 0);

        ammount += msg.value;
        contribs[msg.sender] += msg.value;
        LogDeposit(msg.sender, msg.value);
        return true;
    }

    function withdrawCancelled()
        public
        whenNotPaused
        returns (bool success)
    {
        require(status == States.cancelled);
        uint contrib = contribs[msg.sender];
        require(contrib > 0);

        contribs[msg.sender] = 0;
        msg.sender.transfer(contrib);

        LogWithdrawCancelled(msg.sender, contrib);
        return true;
    }
}
pragma solidity ^0.4.15;

contract Remittance {
    // Structs.
    struct Deposit {
        address author;
        uint balance;
        bytes32 receiverHash;
        uint endDate;
    }

    // Consts.
    uint constant MAX_DEPOSIT_COST = 0.1 finney;
    uint constant MAX_THOUSANDTHS_COST = 10; //1%
    uint constant MAX_DURATION = 31 days;

    // Fields.
    uint public depositedFees;
    mapping (bytes32 => Deposit) public deposits;
    bool public isPaused;
    address public owner;

    // Events.
    event LogChangedPswsHash(address indexed author, bytes32 indexed oldPswsHash, bytes32 indexed newPswsHash);
    event LogDeposit(address indexed author, bytes32 indexed pswHash, uint ammount);
    event LogSwitchPause(bool value);
    event LogWithdrawDeposit(bytes32 indexed pswHash, uint ammount);
    event LogWithdrawFees(uint ammount);

    // Modifiers.
    modifier onlyIfRunning() { require(!isPaused); _; }
    modifier onlyOwner() { require(msg.sender == owner); _; }

    // Costructor.
    function Remittance() {
        owner = msg.sender;
    }

    // Functions.
    function deposit(bytes32 pswHash, uint duration, bytes32 receiverHash)
        public
        onlyIfRunning
        payable
        returns (bool success)
    {
        require(duration <= MAX_DURATION);
        require(deposits[pswHash].author == address(0));
        require(msg.value > 0);

        uint percentageCost = msg.value * MAX_THOUSANDTHS_COST / 1000;
        uint cost = percentageCost < MAX_DEPOSIT_COST ? percentageCost : MAX_DEPOSIT_COST; //min(x, y)

        depositedFees += cost;
        deposits[pswHash] = Deposit({
            author: msg.sender,
            balance: msg.value - cost,
            receiverHash: receiverHash,
            endDate: now + duration
        });

        LogDeposit(msg.sender, pswHash, msg.value);
        return true;
    }

    function switchPause()
        public
        onlyOwner
        returns (bool success)
    {
        isPaused = !isPaused;
        LogSwitchPause(isPaused);
        return true;
    }

    function withdrawDeposit(string psw1, string psw2)
        public
        returns (bool success)
    {
        bytes32 pswHash = keccak256(psw1, psw2);
        require(deposits[pswHash].balance > 0);
        require(deposits[pswHash].receiverHash == keccak256(msg.sender));
        require(now <= deposits[pswHash].endDate);

        uint ammount = deposits[pswHash].balance;
        deposits[pswHash].balance = 0;

        msg.sender.transfer(ammount);

        LogWithdrawDeposit(pswHash, ammount);
        return true;
    }

    function withdrawExpiredDeposit(bytes32 pswHash)
        public
        returns (bool success)
    {
        require(deposits[pswHash].author == msg.sender);
        require(deposits[pswHash].endDate < now);

        uint ammount = deposits[pswHash].balance;
        deposits[pswHash].balance = 0;

        msg.sender.transfer(ammount);

        LogWithdrawDeposit(pswHash, ammount);
        return true;
    }

    function withdrawFees()
        public
        onlyOwner
        returns (bool success)
    {
        uint amount = depositedFees;
        depositedFees = 0;
        owner.transfer(amount);

        LogWithdrawFees(amount);
        return true;
    }
}
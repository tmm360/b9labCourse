pragma solidity ^0.4.13;

contract Remittance {
    // Structs.
    struct Deposit {
        address author;
        uint balance;
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
    event LogDeposit(address indexed author, bytes32 indexed depHash, uint ammount);
    event LogSwitchPause(bool value);
    event LogWithdrawDeposit(bytes32 indexed depHash, uint ammount);
    event LogWithdrawFees(uint ammount);

    // Modifiers.
    modifier onlyIfRunning() { require(!isPaused); _; }
    modifier onlyOwner() { require(msg.sender == owner); _; }

    // Costructor.
    function Remittance()
        public
    {
        owner = msg.sender;
    }

    // Functions.
    function createDepHash(string psw1, string psw2, address addr)
        public
        constant
        returns (bytes32 depHash)
    {
        return keccak256(psw1, psw2, addr);
    }

    function deposit(bytes32 depHash, uint duration)
        public
        onlyIfRunning
        payable
        returns (bool success)
    {
        require(duration <= MAX_DURATION);
        require(deposits[depHash].author == address(0));
        require(msg.value > 0);

        uint percentageCost = msg.value * MAX_THOUSANDTHS_COST / 1000;
        uint cost = percentageCost < MAX_DEPOSIT_COST ? percentageCost : MAX_DEPOSIT_COST; //min(x, y)

        depositedFees += cost;
        deposits[depHash] = Deposit({
            author: msg.sender,
            balance: msg.value - cost,
            endDate: now + duration
        });

        LogDeposit(msg.sender, depHash, msg.value);
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
        bytes32 depHash = createDepHash(psw1, psw2, msg.sender);
        require(deposits[depHash].balance > 0);
        require(now <= deposits[depHash].endDate);

        uint ammount = deposits[depHash].balance;
        deposits[depHash].balance = 0;

        msg.sender.transfer(ammount);

        LogWithdrawDeposit(depHash, ammount);
        return true;
    }

    function withdrawExpiredDeposit(bytes32 depHash)
        public
        returns (bool success)
    {
        require(deposits[depHash].author == msg.sender);
        require(deposits[depHash].endDate < now);

        uint ammount = deposits[depHash].balance;
        deposits[depHash].balance = 0;

        msg.sender.transfer(ammount);

        LogWithdrawDeposit(depHash, ammount);
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
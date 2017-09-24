pragma solidity ^0.4.15;

contract Remittance {
    // Structs.
    struct Deposit {
        uint balance;
        uint startDate;
        uint endDate;
    }

    // Consts.
    uint constant MAX_DEPOSIT_COST = 0.1 finney;
    uint constant MAX_THOUSANDTHS_COST = 10; //1%
    uint constant MAX_DURATION = 31 days;

    // Fields.
    uint public depositedFees;
    mapping (address => mapping (bytes32 => Deposit)) public deposits; //author => psws hash => deposit
    bool public isKilled;
    address public owner;

    // Events.
    event ChangedPswsHashEvent(address indexed author, bytes32 indexed oldPswsHash, bytes32 indexed newPswsHash);
    event DepositEvent(address indexed author, bytes32 indexed pswsHash, uint ammount);
    event KilledEvent();
    event WithdrawDepositEvent(address indexed author, uint ammount);
    event WithdrawFeesEvent(uint ammount);

    // Modifiers.
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Costructor.
    function Remittance() {
        owner = msg.sender;
    }

    // Functions.
    function changePswsHash(bytes32 oldPswsHash, bytes32 newPswsHash)
        public
    {
        require(deposits[msg.sender][newPswsHash].balance == 0);

        deposits[msg.sender][newPswsHash] = deposits[msg.sender][oldPswsHash];
        delete deposits[msg.sender][oldPswsHash];
        
        ChangedPswsHashEvent(msg.sender, oldPswsHash, newPswsHash);
    }

    function deposit(bytes32 pswsHash, uint duration)
        public
        payable
    {
        require(!isKilled);
        require(duration <= MAX_DURATION);
        require(deposits[msg.sender][pswsHash].balance == 0);

        uint cost = min(msg.value * MAX_THOUSANDTHS_COST / 1000, MAX_DEPOSIT_COST);
        depositedFees += cost;
        deposits[msg.sender][pswsHash] = Deposit({
            balance: msg.value - cost,
            startDate: now,
            endDate: now + duration
        });

        DepositEvent(msg.sender, pswsHash, msg.value);
    }

    function kill()
        public
        onlyOwner
    {
        isKilled = true;

        KilledEvent();
    }

    function withdrawDeposit(address author, string psw1, string psw2)
        public
    {
        bytes32 pswsHash = keccak256(psw1, psw2);

        require(now <= deposits[author][pswsHash].endDate);

        withdrawDepositBalance(author, pswsHash);
    }

    function withdrawExpiredDeposit(bytes32 pswsHash)
        public
    {
        require(deposits[msg.sender][pswsHash].endDate < now);

        withdrawDepositBalance(msg.sender, pswsHash);
    }

    function withdrawFees()
        public
        onlyOwner
    {
        uint amount = depositedFees;
        depositedFees = 0;
        owner.transfer(amount);

        WithdrawFeesEvent(amount);
    }

    // Helpers.
    function min(uint a, uint b)
        private
        returns (uint)
    {
        return a < b ? a : b;
    }
    
    function withdrawDepositBalance(address author, bytes32 pswsHash)
        private
    {
        uint ammount = deposits[author][pswsHash].balance;
        delete deposits[author][pswsHash];

        msg.sender.transfer(ammount);

        WithdrawDepositEvent(author, ammount);
    }
}
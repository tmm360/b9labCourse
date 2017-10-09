pragma solidity ^0.4.15;

import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./Collect.sol";

contract CollectHub is Pausable {
    // Fields.
    address[] public collects;
    address public shopfrontAddress;

    // Events.
    event LogNewCollect(address indexed collectContract, address indexed author);
    event LogPausedCollect(address indexed collectContract);
    event LogUnpausedCollect(address indexed collectContract);

    // Constructor.
    function CollectHub(address _shopfrontAddress) {
        shopfrontAddress = _shopfrontAddress;
    }

    // Functions.
    function newCollect(address receiver)
        public
        whenNotPaused
        returns (address collectContract)
    {
        Collect trustedCollect = new Collect(msg.sender, receiver, shopfrontAddress);
        collects.push(trustedCollect);
        LogNewCollect(trustedCollect, msg.sender);
        return trustedCollect;
    }

    function pauseCollect(address collectAddress)
        public
        onlyOwner
        returns (bool success)
    {
        Collect untrustedCollect = Collect(collectAddress);
        untrustedCollect.pause();
        LogPausedCollect(untrustedCollect);
        return true;
    }

    function unpauseCollect(address collectAddress)
        public
        onlyOwner
        returns (bool success)
    {
        Collect untrustedCollect = Collect(collectAddress);
        untrustedCollect.unpause();
        LogUnpausedCollect(untrustedCollect);
        return true;
    }
}
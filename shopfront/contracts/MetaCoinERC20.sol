pragma solidity ^0.4.13;

import "../node_modules/zeppelin-solidity/contracts/token/StandardToken.sol";

contract MetaCoinERC20 is StandardToken {
	// Fields.
    string public constant name = "MetaCoin";
    string public constant symbol = "MTC";
    uint8 public constant decimals = 18;

	// Consts.
    uint256 public constant INITIAL_SUPPLY = 10000 * (10 ** uint256(decimals));

	// Constructor.
	function MetaCoinERC20() {
		totalSupply = INITIAL_SUPPLY;
		balances[msg.sender] = INITIAL_SUPPLY;
	}
}

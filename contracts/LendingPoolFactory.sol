//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "./LendingPoolErc20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingPoolFactory is Ownable {
	mapping(address => address) public poolAddresses;
	LendingPoolErc20[] public poolArray;

	function createPool(address _tokenAddress, string memory _name, string memory _symbol) public onlyOwner {
		require(_tokenAddress != address(0), "Pool can't be for the zero address");
		require(
			!checkIfPoolExists(_tokenAddress),
			"This pool already exists"
		);
		LendingPoolErc20 pool = new LendingPoolErc20(_name, _symbol, _tokenAddress);
		poolArray.push(pool);
		uint index = poolArray.length - 1;
		address lastAddress = address(poolArray[index]);
		poolAddresses[_tokenAddress] = lastAddress;
	}
	
	function checkIfPoolExists(address _tokenAddress) internal view returns (bool) {
    		if (poolAddresses[_tokenAddress] == address(0)) {
      			return false; // Pool doesn't exist
    		}
    		return true; // Pool exists
  	}












}

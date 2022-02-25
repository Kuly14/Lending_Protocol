// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AlphaToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";


contract LendingPoolErc20 is AlphaToken, ReentrancyGuard {

    event TokensDeposited(address indexed _sender, uint indexed _amount);
    event TokensWithdrawn(address indexed _user, uint indexed _amountOfTokens);
    event ExchangeRateChanged(uint indexed _newER);

    IERC20 public token;
    uint public constant baseExchangeRate = 2 * 10**16;
    uint public exchangeRate = baseExchangeRate;

    uint public totalBorrows = 0;
    uint public totalReserves = 0;
    uint public utilizationRate;
    uint public reserveRate = 500; // This number is in basis points so equal to 5%

    constructor(string memory _name, string memory _symbol, address _token) AlphaToken(_name, _symbol) {
        token = IERC20(_token);
    }

    function deposit(uint _amount) public nonReentrant {
        require(token.balanceOf(msg.sender) >= _amount, "Your balance isn't sufficient");
        require(_amount > 0, "The amount can't be 0");

        uint toSend = _calculateErc20Tokens(_amount);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "The transfer didn't go through"
        );
        _mintTokens(toSend);
        emit TokensDeposited(msg.sender, _amount);
    }

    function _mintTokens(uint _amount) private {
        _mint(msg.sender, _amount);
    }

    function _calculateErc20Tokens(uint _deposit) internal returns(uint) {
        _updateExchangeRate();
        uint toknesToSend = (_deposit * 1e18) / exchangeRate;
        return toknesToSend;
    }

    function _updateExchangeRate() private { 
        if (totalSupply() == 0) {
            
        } else {
            exchangeRate = ((_availibleCash() * 1e18) + _totalBorrows() - _getReserves()) / totalSupply();
            emit ExchangeRateChanged(exchangeRate);
        }
    }

    function _availibleCash() internal view returns (uint) {
        return token.balanceOf(address(this));
    }

    function _totalBorrows() internal view returns (uint) {
        return totalBorrows;
    }

    function _getReserves() internal view returns (uint) {
        return totalReserves;
    }



    function withdraw(uint _amountInATokens) public nonReentrant {
        require(balanceOf(msg.sender) >= _amountInATokens, "You are trying to withdraw more than you have");
        require(_amountInATokens > 0, "Amount can't be 0");

        uint toSend = _toSend(_amountInATokens);

        burnTokens(_amountInATokens);

        require(
            token.transfer(msg.sender, toSend),
            "Transfer didn't go through"
        );

        _updateExchangeRate();
        emit TokensWithdrawn(msg.sender, toSend);
    }


    

    function burnTokens(uint _amount) private {
        _burn(msg.sender, _amount);
    }

    function _toSend(uint _amount) internal view returns (uint) {
        uint amountToSend = (_amount * exchangeRate) / 1e18;
        return amountToSend;
    }

    
    function calculateUtilizationRate() internal view returns (uint) {
        if (totalBorrows == 0) { 
            return 0;
        } else { 
            uint URate = totalBorrows * 1e18 / (_availibleCash() + totalBorrows - totalReserves);
            return URate;
        }
    }

    function calculateBorrowRate() internal view returns (uint) {
        
    
    }


    function borrow() public {
        










    }

    function repay() public {

    }

    function totalSup() public view returns(uint) {
        return totalSupply();
    }

}



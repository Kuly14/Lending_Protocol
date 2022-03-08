// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AlphaToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingPoolErc20 is AlphaToken, ReentrancyGuard {

    event TokensDeposited(address indexed _sender, uint indexed _amount);
    event TokensWithdrawn(address indexed _user, uint indexed _amountOfTokens);
    event ExchangeRateChanged(uint indexed _newER);
    event TokensBorrowed(uint indexed _amount, address indexed _caller);
    event TokensRepayed(uint indexed _amount, address indexed _caller);

    IERC20 public token;
    uint public constant baseExchangeRate = 2 * 10**16;
    uint public exchangeRate = baseExchangeRate;

    uint public totalBorrows = 0;
    uint public totalReserves = 0;

    uint public constant baseRate = 1 * 10**16; // 1% or 0.01
    uint public constant baseSlope = 10 * 10**16; // 10% or 0.1
    uint public constant slopeAfterKink = 40 * 10**16; // 40% or 0.4

    uint public constant blocksPerYear = 230675; // Approx amount of block per year

    uint public constant LtvRate = 13500; // 135% in basis points

    uint public utilizationRate;
    uint public constant utilizationRateKink = 80 * 10**16; // 80% utilization rate


    struct Borrower {
        uint borrowedTokens;
        uint collateral;
        uint started;
        uint numOfLoans;
    }

    mapping(address => Borrower) internal borrowers;

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

    function _toSend(uint _amount) public view returns (uint) {
        uint amountToSend = (_amount * exchangeRate) / 1e18;
        return amountToSend;
    }

    
    function calculateUtilizationRate() internal view returns (uint) { // change to internal after testing
        if (totalBorrows == 0) { 
            return 0;
        } else { 
            uint URate = totalBorrows * 1e18 / (_availibleCash() + totalBorrows - totalReserves);
            return URate;
        }
    }

    function calculateBorrowRate() internal view returns(uint) {
        if (calculateUtilizationRate() == 0) {
            return baseRate;
        } else if (calculateUtilizationRate() <= utilizationRateKink) {
            uint bRate = baseRate + (baseSlope * calculateUtilizationRate()) / 1e18;
            return bRate;
        } else if (calculateUtilizationRate() > utilizationRateKink) {
            uint ur = calculateUtilizationRate();
            uint overUR = ur - utilizationRateKink;
            uint rateOverKink = baseRate + (baseSlope * utilizationRateKink / 1e18) + ((overUR * slopeAfterKink) / 1e18);
            return rateOverKink;
        }
    }

    function calculateSupplyRate() public view returns(uint) {
        uint supplyRate = calculateUtilizationRate() * calculateBorrowRate() / 1e18;
        return supplyRate;
    }


    function borrow(uint _amount) public nonReentrant { // _amount is the amount of tokens he wants to borrow
        require(borrowers[msg.sender].numOfLoans == 0, "You can only take out 1 loan");
        require(_amount > 0, "The amount can't be 0");
        uint balanceOfSender = (balanceOf(msg.sender)); // Works
        uint necessaryLtv = getLtv(_amount);
        require(balanceOfSender >= necessaryLtv, "Your balance isn't sufficient to pay the collateral");

        borrowers[msg.sender].borrowedTokens = _amount;
        borrowers[msg.sender].collateral = necessaryLtv; 
        borrowers[msg.sender].started = block.timestamp;
        borrowers[msg.sender].numOfLoans = 1;


        require(
            IERC20(address(this)).transferFrom(msg.sender, address(this), necessaryLtv),
            "Transfer didin't go through"
        );

        require(
            token.transfer(msg.sender, _amount),
            "Transfer did't go through"
        );

        _updateExchangeRate();
        emit TokensBorrowed(_amount, msg.sender);
    }



    function getLtv(uint _amount) public view returns(uint) {
        uint coll = _amount * LtvRate / 10000;
        uint amountToReceive = (coll * 1e18) / exchangeRate;
        return amountToReceive;

    }

    function repay() public nonReentrant {
        require(borrowers[msg.sender].numOfLoans == 1, "You don't have any tokens borrowed");
        uint amountToPayBack = _calculateInterestOfBorrower();
        uint collateral = borrowers[msg.sender].collateral;


        borrowers[msg.sender].borrowedTokens = 0;
        borrowers[msg.sender].collateral = 0; 
        borrowers[msg.sender].started = 0;
        borrowers[msg.sender].numOfLoans = 0;


        require(
            token.transferFrom(msg.sender, address(this), amountToPayBack),
            "Transfer didn't go through"
        );

        require(
            IERC20(address(this)).transfer(msg.sender, collateral),
            "Transfer didn't go through"
        );

        _updateExchangeRate();
        emit TokensRepayed(amountToPayBack, msg.sender);
    }

    function _calculateInterestOfBorrower() internal view returns (uint) { // change to internal after testing
        uint borrowRate = calculateBorrowRate();
        uint interestPerBlock = borrowRate / blocksPerYear;
        uint numOfBlocks = block.timestamp - borrowers[msg.sender].started;
        uint interestForTheCaller = numOfBlocks * interestPerBlock; 
        uint interestInTokens = (borrowers[msg.sender].borrowedTokens * interestForTheCaller) / 1e18;
        uint amountToPayBack = interestInTokens + borrowers[msg.sender].borrowedTokens;
        return amountToPayBack;
    }
}
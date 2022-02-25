// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AlphaToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract LendingPoolEth is AlphaToken, ReentrancyGuard {

    constructor(string memory _name, string memory _symbol) AlphaToken(_name, _symbol) {}

    function deposit() public payable nonReentrant {
        










    }

    function withdraw() public {

    }

    function borrow() public {

    }

    function liquidate() public {

    }

    function repay() public {

    }


    // fallback() external payable {
    //     msg.sender.call{value: msg.value};
    // }



}



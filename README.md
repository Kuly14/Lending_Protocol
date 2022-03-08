# Alpha Lending Pool

## Description

This is Lending Protocol inspired by compound architecture. The pool will always let you borrow funds if there is enough tokens in the pool to fulfill the request.

The interest rate is based on supply and demand. If there is lot of borrowing the rate is high and vice versa. 

## Outline

This project consists of 2 contracts. The LendingPoolFactory.sol and LendingPoolErc20.sol.

### LendingPoolErc20.sol

This is the main contract the user will interact with. This is also the contract that will hold all the funds and let users borrow funds. 

It also calculates all of the important rates. And does all the work. 

Here is an example in steps: 

#### 1. Approve The Pool.

To deposit tokens into the pool you will have to approve it first in the weth contract.

#### 2. Deposit Tokens. 

You call the `deposit("amount you want to deposit")` function
This function will transfer the tokens from you to the contract and will write your balance to the database(mapping). 

It will also mint aTokens in this case aWeth. These tokens represent how much tokens you have in the contract. 

The balance is calculated with the exchange rate which is slowly adjusting to the upside. So if you deposit some tokens and take them out a week later.
If there has been some borrowing your aTokens are more valueable.

#### 3. Borrow Tokens

In this version I wrote the contract so you can borrow only the same tokens you have deposited. This makes the app less 
complex and less prone to hacks since we are not using any price feeds. 

Every loan has to be overcollateralized by at least 135%. So to borrow the tokens just call `borrow("amount you want to borrow")` function. 

This function will calculate if you have enough tokens in the contract to deposit collateral for it. If you don't the function will revert. 

If you have enough tokens to put down as collateral the function will send you the tokens. And take aTokens as collateral.

Of course you will have to pay interest rate which is higher or lower depending on how many users are borrowing and depositing.

You can now go and use the tokens however you want.


#### 4. Repay The Loan. 

To repay the loan back just call `repay()` function. It will check if you have enough tokens to repay the loan. 
If you do it will take the tokens back and release the collateral back to you. In this case aTokens tokens.

#### 5. Withdrawing tokens.

To withdraw the tokens just call `withdraw("Amount you want to withdraw")` function. The contract will check if you 
have enough aTokens and then will take your aTokens and trade them for the token that has been in the contract.


### LendingPoolFactory.sol

This contract will create the pools. Only the owner has access to these functions. In the future the owner will be a governance contract and the comunity will vote to let's say change params and so on. 

Very simmilar like in the compound protocol.


# Conclusion

This version was just a proof of concept if you will. I will create another version that will allow users to put down any token that has been approved by the community and borrow any other approved token. 

I will also create a DAO around it so it will be completely decentralized.

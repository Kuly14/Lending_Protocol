const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("LendingPoolErc20", function () {

  let user;
  let user2;
  let LendingPool;
  let pool;
  let MockToken;
  let token;

  before(async function () {
    [user, user2, ...addrs] = await ethers.getSigners();

    MockToken = await ethers.getContractFactory("MockToken")
    token = await MockToken.connect(user).deploy();
    await token.deployed();

    LendingPool = await ethers.getContractFactory("LendingPoolErc20")
    pool = await LendingPool.deploy(
      "aMCK",
      "aMCK",
      token.address
    );
    await pool.deployed();
  });

  describe("Pool Tests", function () {

    it("Should check if the contracts were deployed correctly", async function () {
      
      const ER = await pool.exchangeRate();

      expect(ER).to.equal(ethers.utils.parseEther("0.02"));
    });

    it("Should deposit tokens and get aTokens back", async function () {

      const bal = await token.balanceOf(user.address);
      const approve_tx = await token.connect(user).approve(pool.address, bal);
      const depositTokens = await pool.connect(user).deposit(ethers.utils.parseEther("10"));
      
      // check balances
      expect(await token.balanceOf(pool.address)).to.equal(ethers.utils.parseEther("10"))
      expect(await pool.balanceOf(user.address)).to.equal(ethers.utils.parseEther("500"));
      expect(await pool.totalSupply()).to.equal(ethers.utils.parseEther("500"))
      
      // Check if event was emmited correctly
      await expect(pool.connect(user).deposit(ethers.utils.parseEther("10")))
        .to.emit(pool, "TokensDeposited")
        .withArgs(user.address, ethers.utils.parseEther("10"));

      // Check if the require statements are correct
      await expect(pool.deposit(0)).to.be.revertedWith("The amount can't be 0");
      await expect(pool.connect(user2).deposit(ethers.utils.parseEther("10")))
        .to.be.revertedWith("Your balance isn't sufficient")
    });

    it("Should deposit again and check if the exchange reate is correct", async function () {
      await pool.connect(user).deposit(ethers.utils.parseEther("10"));
      const ExchangeR = await pool.exchangeRate();
      
      // This time the rate is calculated in _updateExchangeRate() function. This shows that the calculations are correct
      // Because no tokens were borrowed so the exchange rate should be same
      expect(ExchangeR).to.equal(ethers.utils.parseEther("0.02"));

      // Checks if all deposits were successful
      expect(await token.balanceOf(pool.address)).to.equal(ethers.utils.parseEther("30"));

      // Checks if the math was correct
      expect(await pool.balanceOf(user.address)).to.equal(ethers.utils.parseEther("1500"));
    });


    it("Should borrow Tokens", async function () {
      const approve_tx = pool.connect(user).approve(pool.address, ethers.utils.parseEther("10000"));

      await expect(pool.connect(user).borrow(ethers.utils.parseEther("0")))
      .to.be.revertedWith("The amount can't be 0");

      await expect(pool.connect(user).borrow(ethers.utils.parseEther("50")))
      .to.be.revertedWith("Your balance isn't sufficient to pay the collateral");
      
      await expect(pool.connect(user).borrow(ethers.utils.parseEther("7")))
      .to.emit(pool, "TokensBorrowed")
      .withArgs(
        ethers.utils.parseEther("7"),
        user.address
      );

      // Check if the balance increased by 7
      expect(await token.balanceOf(user.address)).to.equal(ethers.utils.parseEther("99977"));
      // Check if the balance of aTokens are less and are locked in the contract
      expect(await pool.balanceOf(user.address)).to.be.eq(ethers.utils.parseEther("1027.5"));
      // Chekc if the 1500 - 1027.5 is equal to the balance of the pool
      expect(await pool.balanceOf(pool.address)).to.be.eq(ethers.utils.parseEther("472.5"));
      // Check if the balance is eq to 30(Balance before) - 7(borrowed Tokens)
      expect(await token.balanceOf(pool.address)).to.be.eq(ethers.utils.parseEther("23"));
  
      // Check if the require statements are correct
      await expect(pool.connect(user).borrow(ethers.utils.parseEther("7")))
      .to.be.revertedWith("You can only take out 1 loan");
    });

    it("Should repay the tokens with interest", async function () {

      // Increase time so the the loan will accumulate som interest rate
      await network.provider.send("evm_increaseTime", [3600 * 30]); // one month
      await network.provider.send("evm_mine")

      await expect(pool.connect(user).repay())
      .to.emit(pool, "TokensRepayed")
      .withArgs("7032773989378270070", user.address);

      await expect(pool.connect(user2).repay()).to.be.revertedWith("You don't have any tokens borrowed");

    })

    it("Should withdraw funds", async function () {
      await pool.withdraw(ethers.utils.parseEther("1500"));

      expect(await pool.balanceOf(user.address)).to.be.eq(0);
      // Somethimes there can be a little missmatch in the math so the tokens won't be exact
      expect(await token.balanceOf(user.address)).to.be.gt("99999999999999999999920")

      // Checks if require statements are working
      await expect(pool.withdraw(ethers.utils.parseEther("2000")))
        .to.be.revertedWith("You are trying to withdraw more than you have");

      await expect(pool.withdraw(0)).to.be.revertedWith("Amount can't be 0");
    });
  });
});

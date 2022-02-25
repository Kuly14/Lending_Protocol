const { expect } = require("chai");
const { ethers } = require("hardhat");

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
      const RR = await pool.reserveRate();

      expect(RR).to.equal(500);
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

    it("Should withdraw funds", async function () {
      await pool.withdraw(ethers.utils.parseEther("1500"));
      
      // checks if tokens were burned and transfered correctly
      expect(await pool.balanceOf(user.address)).to.equal(0);
      expect(await token.balanceOf(pool.address)).to.equal(0);

      // Checks if require statements are working
      await expect(pool.withdraw(ethers.utils.parseEther("2000")))
        .to.be.revertedWith("You are trying to withdraw more than you have");

      await expect(pool.withdraw(0)).to.be.revertedWith("Amount can't be 0");

    });
  });
});

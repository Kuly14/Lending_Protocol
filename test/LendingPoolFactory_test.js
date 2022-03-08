const { expect } = require("chai");
const { ethers, network } = require("hardhat");


describe("LendingPoolErc20", function () {

  let user;
  let user2;
  let Factory;
  let fac;
  let MockToken;
  let token;

  before(async function () {
    [user, user2, ...addrs] = await ethers.getSigners();

    MockToken = await ethers.getContractFactory("MockToken")
    token = await MockToken.connect(user).deploy();
    await token.deployed();

    Factory = await ethers.getContractFactory("LendingPoolFactory")
    fac = await Factory.connect(user).deploy();
    await fac.deployed();
  });

  describe("Factory Tests", function () {
    it("Should deploy new pool", async function () {
      await fac.createPool(
        token.address,
        "aMockToken",
        "aMock"
      );

      await expect(fac.createPool(
        token.address,
        "aMockToken",
        "aMock"
      )).to.be.revertedWith("This pool already exists")
    });


    it("Should interact with the new pool", async function () {
      const addr = await fac.poolAddresses(token.address);
      const pool = await (await ethers.getContractFactory("LendingPoolErc20")).attach(addr);

      await token.approve(pool.address, ethers.utils.parseEther("100000"))

      await pool.deposit(ethers.utils.parseEther("10"))

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

    // Rest of the tests are in the LendingPoolErc20_test.js file.
  });
});

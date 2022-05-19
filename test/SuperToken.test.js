const { expect } = require("chai");
const { ethers, config } = require("hardhat");

describe("SuperToken Contract", () => {
  let superTokenContract;
  let owner;
  const params = config.projectParams;

  describe("constructor", () => {
    before(async () => {
      const SuperToken = await ethers.getContractFactory("SuperToken");
      superTokenContract = await SuperToken.deploy(
        params.TOKEN_NAME,
        params.TOKEN_SYMBOL,
        params.TOTAL_SUPPLY
      );

      [owner] = await ethers.getSigners();
    });

    it("should set the right owner", async () => {
      expect(await superTokenContract.owner()).to.equal(owner.address);
    });

    it("should set the right tokenName", async () => {
      expect(await superTokenContract.name()).to.equal("SuperToken");
    });

    it("should set the right tokenSymbol", async () => {
      expect(await superTokenContract.symbol()).to.equal("ST");
    });

    it("should set the right totalSupply", async () => {
      expect(await superTokenContract.totalSupply()).to.equal(
        ethers.utils.parseEther(params.TOTAL_SUPPLY.toString())
      );
    });

    it("should assign the total supply of tokens to the owner", async () => {
      const ownerBalance = await superTokenContract.balanceOf(owner.address);
      expect(await superTokenContract.totalSupply()).to.equal(ownerBalance);
    });
  });
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SuperAppToken Contract", () => {
  let superAppTokenInstance;
  let owner;
  const decimals = 18;
  const totalSupply = ethers.utils.parseUnits("1", decimals);

  beforeEach(async () => {
    const SuperAppToken = await ethers.getContractFactory("SuperAppToken");
    superAppTokenInstance = await SuperAppToken.deploy();
    [owner] = await ethers.getSigners();
  });

  describe("Deployment", () => {
    it("should set the right owner", async () => {
      expect(await superAppTokenInstance.owner()).to.equal(owner.address);
    });

    it("should set tokenName", async () => {
      expect(await superAppTokenInstance.name()).to.equal("SuperApp");
    });

    it("should set tokenSymbol", async () => {
      expect(await superAppTokenInstance.symbol()).to.equal("SPA");
    });

    it("should set totalSupply", async () => {
      expect(await superAppTokenInstance.totalSupply()).to.equal(totalSupply);
    });

    it("should assign the total supply of tokens to the owner", async () => {
      const ownerBalance = await superAppTokenInstance.balanceOf(owner.address);
      expect(await superAppTokenInstance.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("Staking", () => {
    it("can not stake more than balance", async () => {
      await expect(
        superAppTokenInstance.stake(ethers.utils.parseUnits("3", decimals))
      ).to.be.revertedWith("SuperAppToken: Can not stake more than you own");
    });

    it("can not stake zero balance", async () => {
      await expect(superAppTokenInstance.stake(0)).to.be.revertedWith(
        "Can not stake nothing"
      );
    });
  });
});

const { expect } = require("chai");
const { ethers, config } = require("hardhat");

describe("MultiSigWallet Contract", () => {
  let MultiSigWallet;
  let tokenContract;
  let owner1;
  let owner2;
  let owner3;
  let user1;
  let user2;
  const params = config.projectParams;

  before(async () => {
    [owner1, owner2, owner3, user1, user2] = await ethers.getSigners();
    const SuperToken = await ethers.getContractFactory("SuperToken");

    tokenContract = await SuperToken.deploy(
      params.TOKEN_NAME,
      params.TOKEN_SYMBOL
    );
    MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
  });

  describe("constructor", () => {
    it("should throw an error when no owner provided", async () => {
      await expect(
        MultiSigWallet.deploy([], 2, tokenContract.address)
      ).to.be.revertedWith("MultiSigWallet: owners required");
    });

    it("should throw an error when requiredConfirmationCount is equal to 0", async () => {
      await expect(
        MultiSigWallet.deploy(
          [owner1.address, owner2.address, owner3.address],
          0,
          tokenContract.address
        )
      ).to.be.revertedWith(
        "MultiSigWallet: invalid number of required confirmations"
      );
    });

    it("should throw an error when requiredConfirmationCount is greater than owners.length", async () => {
      await expect(
        MultiSigWallet.deploy(
          [owner1.address, owner2.address, owner3.address],
          4,
          tokenContract.address
        )
      ).to.be.revertedWith(
        "MultiSigWallet: invalid number of required confirmations"
      );
    });

    it("should throw an error when an owner is zero address", async () => {
      await expect(
        MultiSigWallet.deploy(
          [ethers.constants.AddressZero, owner1.address, owner2.address],
          3,
          tokenContract.address
        )
      ).to.be.revertedWith("MultiSigWallet: invalid owner");
    });

    it("should throw an error when owners are not unique", async () => {
      await expect(
        MultiSigWallet.deploy(
          [owner1.address, owner1.address, owner2.address],
          3,
          tokenContract.address
        )
      ).to.be.revertedWith("MultiSigWallet: owner not unique");
    });

    it("should initialize the contract properly", async () => {
      const multiSigWalletContract = await MultiSigWallet.deploy(
        [owner1.address, owner2.address, owner3.address],
        3,
        tokenContract.address
      );

      expect((await multiSigWalletContract.getOwners()).length).to.eq(3);

      expect(await multiSigWalletContract.isOwner(owner1.address)).to.eq(true);
      expect(await multiSigWalletContract.isOwner(owner2.address)).to.eq(true);
      expect(await multiSigWalletContract.isOwner(owner3.address)).to.eq(true);
    });
  });

  describe("submitTransaction", () => {
    let multiSigWalletContract;
    before(async () => {
      multiSigWalletContract = await MultiSigWallet.deploy(
        [owner1.address, owner2.address, owner3.address],
        3,
        tokenContract.address
      );
    });

    it("should throw an error when called from non-owner account", async () => {
      await expect(
        multiSigWalletContract
          .connect(user1)
          .submitTransaction(
            user2.address,
            ethers.utils.parseEther("10"),
            "0x",
            false
          )
      ).to.be.revertedWith("MultiSigWallet: caller is not the owner");
    });

    it("should add the transaction to storage with the right arguments", async () => {
      const oldTransactionCount =
        await multiSigWalletContract.getTransactionCount();

      await multiSigWalletContract.submitTransaction(
        user2.address,
        ethers.utils.parseEther("10"),
        "0x",
        false
      );

      expect(await multiSigWalletContract.getTransactionCount()).to.eq(
        oldTransactionCount + 1
      );
    });
  });
});

const { expect } = require("chai");
const { ethers, config, waffle } = require("hardhat");

const provider = waffle.provider;

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
      params.TOKEN_SYMBOL,
      params.TOTAL_SUPPLY
    );
    MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
  });

  describe("constructor", () => {
    it("should throw an error when no owner provided", async () => {
      await expect(
        MultiSigWallet.deploy([], 2, tokenContract.address)
      ).revertedWith("MultiSigWallet: owners required");
    });

    it("should throw an error when requiredConfirmationCount is equal to 0", async () => {
      await expect(
        MultiSigWallet.deploy(
          [owner1.address, owner2.address, owner3.address],
          0,
          tokenContract.address
        )
      ).revertedWith(
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
      ).revertedWith(
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
      ).revertedWith("MultiSigWallet: invalid owner");
    });

    it("should throw an error when owners are not unique", async () => {
      await expect(
        MultiSigWallet.deploy(
          [owner1.address, owner1.address, owner2.address],
          3,
          tokenContract.address
        )
      ).revertedWith("MultiSigWallet: owner not unique");
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
      ).revertedWith("MultiSigWallet: caller is not the owner");
    });

    it("should add the transaction to the storage with the right arguments then emit TransactionSubmitted event", async () => {
      const value = ethers.utils.parseEther("10");
      const data = "0x";
      const oldTransactionCount =
        await multiSigWalletContract.getTransactionCount();

      const tx = await multiSigWalletContract.submitTransaction(
        user2.address,
        value,
        data,
        false
      );

      expect(await multiSigWalletContract.getTransactionCount()).to.eq(
        oldTransactionCount + 1
      );

      expect(tx).to.emit(
        owner1.address,
        oldTransactionCount,
        user2.address,
        value,
        data,
        false
      );
    });
  });

  describe("confirmTransaction", () => {
    let multiSigWalletContract;
    const value = ethers.utils.parseEther("10");
    const data = "0x";
    const txIndex = 0;
    before(async () => {
      multiSigWalletContract = await MultiSigWallet.deploy(
        [owner1.address, owner2.address, owner3.address],
        2,
        tokenContract.address
      );

      await multiSigWalletContract.submitTransaction(
        user1.address,
        value,
        data,
        false
      );
    });

    it("should throw an error when called from non-owner account", async () => {
      await expect(
        multiSigWalletContract.connect(user1).confirmTransaction(txIndex)
      ).revertedWith("MultiSigWallet: caller is not the owner");
    });

    it("should throw an error when tx does not exist", async () => {
      await expect(multiSigWalletContract.confirmTransaction(1)).revertedWith(
        "MultiSigWallet: tx does not exist"
      );
    });

    it("should confirm the transaction then emit TransactionConfirmed event", async () => {
      const tx = await multiSigWalletContract.confirmTransaction(txIndex);

      const confirmedTransaction = await multiSigWalletContract.transactions(
        txIndex
      );

      expect(confirmedTransaction.confirmationCount).eq(1);
      expect(
        await multiSigWalletContract.isConfirmed(txIndex, owner1.address)
      ).eq(true);
      expect(tx).emit(owner1.address, txIndex);
    });

    it("should throw an error when tx is already confirmed", async () => {
      await expect(multiSigWalletContract.confirmTransaction(0)).revertedWith(
        "MultiSigWallet: tx already confirmed"
      );
    });

    it("should throw an error when tx is already executed", async () => {
      await owner1.sendTransaction({
        to: multiSigWalletContract.address,
        value: ethers.utils.parseEther("10"),
      });
      await multiSigWalletContract.connect(owner2).confirmTransaction(txIndex);
      await multiSigWalletContract.executeTransaction(txIndex);

      await expect(
        multiSigWalletContract.confirmTransaction(txIndex)
      ).revertedWith("MultiSigWallet: tx already executed");
    });
  });

  describe("executeTransaction", () => {
    let multiSigWalletContract;
    const value = ethers.utils.parseEther("10");
    const data = "0x";
    const txIndex = 0;
    before(async () => {
      multiSigWalletContract = await MultiSigWallet.deploy(
        [owner1.address, owner2.address, owner3.address],
        2,
        tokenContract.address
      );

      await multiSigWalletContract.submitTransaction(
        user1.address,
        value,
        data,
        false
      );
    });

    it("should throw an error when called from non-owner account", async () => {
      await expect(
        multiSigWalletContract.connect(user1).executeTransaction(txIndex)
      ).revertedWith("MultiSigWallet: caller is not the owner");
    });

    it("should throw an error when tx does not exist", async () => {
      await expect(multiSigWalletContract.executeTransaction(1)).revertedWith(
        "MultiSigWallet: tx does not exist"
      );
    });

    it("should throw an error when not enough confirmations", async () => {
      await expect(
        multiSigWalletContract.executeTransaction(txIndex)
      ).revertedWith("MultiSigWallet: not enough confirmations");
    });

    it("should throw an error when withdrawal amount is greater than contract's balance", async () => {
      await owner1.sendTransaction({
        to: multiSigWalletContract.address,
        value: ethers.utils.parseEther("9"),
      });

      await multiSigWalletContract.confirmTransaction(txIndex);
      await multiSigWalletContract.connect(owner2).confirmTransaction(txIndex);

      await expect(
        multiSigWalletContract.executeTransaction(txIndex)
      ).revertedWith("MultiSigWallet: tx failed");
    });

    it("should execute the transaction successfully then emit TransactionExecuted event", async () => {
      await owner1.sendTransaction({
        to: multiSigWalletContract.address,
        value: ethers.utils.parseEther("1"),
      });

      const oldBalance = await provider.getBalance(
        multiSigWalletContract.address
      );

      const tx = await multiSigWalletContract.executeTransaction(txIndex);

      const executedTransaction = await multiSigWalletContract.transactions(
        txIndex
      );

      expect(await provider.getBalance(multiSigWalletContract.address)).eq(
        oldBalance.sub(value)
      );
      expect(executedTransaction.executed).eq(true);
      expect(tx).emit(owner1.address, txIndex);
    });

    it("should throw an error when tx already executed", async () => {
      await expect(
        multiSigWalletContract.executeTransaction(txIndex)
      ).revertedWith("MultiSigWallet: tx already executed");
    });

    it("should execute ERC20 transaction successfully then emit TransactionExecuted event", async () => {
      await tokenContract.transfer(
        multiSigWalletContract.address,
        ethers.utils.parseEther("10")
      );

      await multiSigWalletContract.submitTransaction(
        user1.address,
        ethers.utils.parseEther("10"),
        data,
        true
      );

      await multiSigWalletContract.confirmTransaction(1);
      await multiSigWalletContract.connect(owner2).confirmTransaction(1);

      const oldBalance = await tokenContract.balanceOf(
        multiSigWalletContract.address
      );

      const tx = await multiSigWalletContract.executeTransaction(1);

      const executedTransaction = await multiSigWalletContract.transactions(1);

      expect(await tokenContract.balanceOf(multiSigWalletContract.address)).eq(
        oldBalance.sub(value)
      );
      expect(executedTransaction.executed).eq(true);
      expect(tx).emit(owner1.address, txIndex);
    });
  });

  describe("revokeConfirmation", () => {
    let multiSigWalletContract;
    const value = ethers.utils.parseEther("10");
    const data = "0x";
    const txIndex = 0;
    before(async () => {
      multiSigWalletContract = await MultiSigWallet.deploy(
        [owner1.address, owner2.address, owner3.address],
        2,
        tokenContract.address
      );

      await multiSigWalletContract.submitTransaction(
        user1.address,
        value,
        data,
        false
      );
    });

    it("should throw an error when called from non-owner account", async () => {
      await expect(
        multiSigWalletContract.connect(user1).revokeConfirmation(txIndex)
      ).revertedWith("MultiSigWallet: caller is not the owner");
    });

    it("should throw an error when tx does not exist", async () => {
      await expect(multiSigWalletContract.revokeConfirmation(1)).revertedWith(
        "MultiSigWallet: tx does not exist"
      );
    });

    it("should throw an error when tx not confirmed", async () => {
      await expect(
        multiSigWalletContract.revokeConfirmation(txIndex)
      ).revertedWith("MultiSigWallet: tx not confirmed");
    });

    it("should revoke the confirmation successfully then emit ConfirmationRevoked event", async () => {
      await multiSigWalletContract.confirmTransaction(txIndex);

      const oldTransactionCount = (
        await multiSigWalletContract.transactions(txIndex)
      ).confirmationCount;

      const tx = await multiSigWalletContract.revokeConfirmation(txIndex);

      expect(
        (await multiSigWalletContract.transactions(txIndex)).confirmationCount
      ).eq(oldTransactionCount - 1);

      expect(
        await multiSigWalletContract.isConfirmed(txIndex, owner1.address)
      ).eq(false);

      expect(tx).emit(owner1.address, txIndex);
    });

    it("should throw an error when tx already executed", async () => {
      await owner1.sendTransaction({
        to: multiSigWalletContract.address,
        value: ethers.utils.parseEther("10"),
      });

      await multiSigWalletContract.confirmTransaction(txIndex);
      await multiSigWalletContract.connect(owner2).confirmTransaction(txIndex);
      await multiSigWalletContract.executeTransaction(txIndex);

      await expect(
        multiSigWalletContract.revokeConfirmation(txIndex)
      ).revertedWith("MultiSigWallet: tx already executed");
    });
  });
});

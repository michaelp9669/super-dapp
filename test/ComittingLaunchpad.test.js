const { expect } = require("chai");
const { ethers, config, waffle } = require("hardhat");

// const provider = waffle.provider;

describe("CommittingLaunchpad Contract", () => {
  let committingLaunchpadContract;
  let tokenContract;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  const params = config.projectParams;

  async function setupBefore() {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const SuperToken = await ethers.getContractFactory("SuperToken");

    tokenContract = await SuperToken.deploy(
      params.TOKEN_NAME,
      params.TOKEN_SYMBOL,
      params.TOTAL_SUPPLY
    );

    const CommittingLaunchpad = await ethers.getContractFactory(
      "CommittingLaunchpad"
    );

    committingLaunchpadContract = await CommittingLaunchpad.deploy();
  }

  describe("launch", () => {
    before(setupBefore);

    it("should throw an error when called from non-owner account", async () => {
      const currentTimeStamp = Date.now();
      await expect(
        committingLaunchpadContract
          .connect(addr1)
          .launch(
            tokenContract.address,
            currentTimeStamp,
            currentTimeStamp + 7 * 60 * 60 * 24,
            50000,
            1000000000,
            100000000000000
          )
      ).revertedWith("Ownable: caller is not the owner");
    });
  });
});

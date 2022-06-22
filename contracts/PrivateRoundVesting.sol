// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract PrivateRoundVesting is VestingWallet {
    constructor(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) VestingWallet(beneficiary, startTimestamp, durationSeconds) {}

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp)
        internal
        view
        override(VestingWallet)
        returns (uint256)
    {
        uint256 CLIFF_SECONDS = 90 days;

        if (timestamp < start() + CLIFF_SECONDS) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return
                totalAllocation /
                2 +
                ((totalAllocation / 2) *
                    (timestamp - start() - CLIFF_SECONDS)) /
                (duration() - CLIFF_SECONDS);
        }
    }
}

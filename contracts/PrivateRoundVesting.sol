// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

/**
 * @dev 50% becomes freely transferable after a 90 days cliff
 * the remaining will unlock linearly over 1 year
 * so the durationSeconds will be equal to 90 days + 365 days
 */
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

    function _asmVestingSchedule(
        uint256 totalAllocation,
        uint64 currentTimestamp
    ) internal view returns (uint256 r) {
        uint256 start = start();
        assembly {
            let cliffSeconds := mul(mul(mul(90, 24), 60), 60)
            mstore(0x00, cliffSeconds)
            mstore(0x20, currentTimestamp)
            mstore(0x40, start)
            if lt(0x20, add(0x40, 0x00)) {
                return(0, 32)
            }
        }
    }
}

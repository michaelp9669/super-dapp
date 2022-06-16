//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "hardhat/console.sol";

contract CommittingLaunchpad is Ownable, Pausable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct Launchpad {
        // pack into 32-byte slot
        IERC20 tokenContract;
        uint48 startTime;
        uint48 endTime;
        //
        uint256 hardCap;
        uint256 offeredAmount;
        uint256 initialPrice;
        uint256 participantCount;
        uint256 totalCommitted;
    }

    uint256 public constant SECOND_PER_DAY = 60 * 60 * 24;
    uint256 public launchpadCount;
    mapping(uint256 => Launchpad) public launchpads;
    mapping(uint256 => EnumerableMap.AddressToUintMap)
        private _committedAmountOf;
    mapping(uint256 => mapping(address => uint256))
        public averageCommittedAmountOf;
    mapping(uint256 => mapping(address => uint256)) public allocations;

    event Launched();
    event Committed(uint256 amount);
    event Claimed();
    event Canceled();

    modifier whenHappening(uint256 id) {
        Launchpad storage launchpad = launchpads[id];

        // require(
        //     block.timestamp >= launchpad.startTime,
        //     "CommittingLaunchpad: launchpad not started"
        // );
        // require(
        //     block.timestamp <= launchpad.endTime,
        //     "CommittingLaunchpad: launchpad ended"
        // );

        _;
    }

    modifier whenEnded(uint256 id) {
        Launchpad storage launchpad = launchpads[id];
        require(block.timestamp > launchpad.endTime);
        _;
    }

    modifier notZeroAmount(uint256 amount) {
        require(amount > 0, "CommittingLaunchpad: zero amount not allowed");
        _;
    }

    receive() external payable {}

    function committedAmountOf(uint256 id, address account)
        public
        view
        returns (uint256)
    {
        return _committedAmountOf[id].get(account);
    }

    function launch(
        address tokenContract,
        uint48 startTime,
        uint48 endTime,
        uint256 hardCap,
        uint256 offeredAmount,
        uint256 initialPrice
    ) external onlyOwner {
        // require(
        //     startTime >= block.timestamp,
        //     "CommittingLaunchpad: startTime must be >= now"
        // );
        // require(
        //     endTime >= startTime,
        //     "CommittingLaunchpad: endTime must be >= startTime"
        // );
        // require(
        //     startTime >= block.timestamp + 1 days,
        //     "CommittingLaunchpad: startTime must be >= min duration"
        // );
        // require(
        //     endTime <= block.timestamp + 90 days,
        //     "CommittingLaunchpad: endTime must be <= max duration"
        // );
        
        require(
            hardCap <= offeredAmount,
            "CommittingLaunchpad: hardCap must be less than or equal offeredAmount"
        );

        launchpadCount += 1;
        launchpads[launchpadCount] = Launchpad({
            tokenContract: IERC20(tokenContract),
            startTime: startTime,
            endTime: endTime,
            hardCap: hardCap,
            offeredAmount: offeredAmount,
            initialPrice: initialPrice,
            totalCommitted: 0,
            participantCount: 0
        });
    }

    function cancel(uint256 id) external onlyOwner {
        Launchpad storage launchpad = launchpads[id];
        require(
            block.timestamp < launchpad.startTime,
            "CommittingLaunchpad: launchpad already started"
        );

        delete launchpads[id];
        emit Canceled();
    }

    function commit(uint256 id)
        external
        payable
        whenNotPaused
        /// whenHappening(id)
        notZeroAmount(msg.value)
    {
        Launchpad storage launchpad = launchpads[id];
        launchpad.totalCommitted += msg.value;

        (
            bool notFirstCommit,
            uint256 currentCommittedAmount
        ) = _committedAmountOf[id].tryGet(msg.sender);

        if (notFirstCommit) {
            uint256 daysOfDuration = _daysFromTimestamp(
                launchpad.endTime - launchpad.startTime
            );
            uint256 currentDay = _daysFromTimestamp(
                block.timestamp - launchpad.startTime
            );

            averageCommittedAmountOf[id][msg.sender] =
                (currentCommittedAmount *
                    (daysOfDuration - 1) +
                    (currentCommittedAmount + msg.value) *
                    (daysOfDuration - currentDay - 1)) /
                daysOfDuration;
        } else {
            launchpad.participantCount += 1;
            averageCommittedAmountOf[id][msg.sender] = msg.value;
        }
        _committedAmountOf[id].set(
            msg.sender,
            currentCommittedAmount + msg.value
        );
    }

    function uncommit(uint256 id, uint256 amount)
        external
        whenNotPaused
        whenHappening(id)
        notZeroAmount(amount)
    {
        (
            bool notFirstCommit,
            uint256 currentCommittedAmount
        ) = _committedAmountOf[id].tryGet(msg.sender);

        require(notFirstCommit, "CommittingLaunchpad: not a participant");
        require(
            amount <= currentCommittedAmount,
            "CommittingLaunchpad: Exceeded committed amount"
        );

        Launchpad storage launchpad = launchpads[id];
        launchpad.totalCommitted -= amount;
        if (amount == _committedAmountOf[id].get(msg.sender)) {
            launchpad.participantCount -= 1;
            averageCommittedAmountOf[id][msg.sender] = 0;
        } else {
            uint256 daysOfDuration = _daysFromTimestamp(
                launchpad.endTime - launchpad.startTime
            );
            uint256 currentDay = _daysFromTimestamp(
                block.timestamp - launchpad.startTime
            );

            averageCommittedAmountOf[id][msg.sender] =
                (currentCommittedAmount *
                    (daysOfDuration - 1) +
                    (currentCommittedAmount - amount) *
                    (daysOfDuration - currentDay - 1)) /
                daysOfDuration;
        }
        _committedAmountOf[id].set(msg.sender, currentCommittedAmount - amount);
        (bool sent, ) = payable(msg.sender).call{value: amount}("");

        require(sent, "CommittingLaunchpad: failed to transfer Ether");
    }

    function calculateAllocations(uint256 id) external onlyOwner {
        Launchpad storage launchpad = launchpads[id];

        uint256 remainingCap;
        uint256 exceededCount;
        for (uint256 i = 0; i < launchpad.participantCount; i++) {
            (address participant, ) = _committedAmountOf[id].at(i);

            /// @note percentage of committed over totalCommitted x offered amount for the sale
            uint256 individualCap = (averageCommittedAmountOf[id][participant] *
                launchpad.offeredAmount) / launchpad.totalCommitted;

            if (individualCap > launchpad.hardCap) {
                remainingCap += individualCap - launchpad.hardCap;
                exceededCount += 1;
                allocations[id][participant] = launchpad.hardCap;
            } else {
                allocations[id][participant] = individualCap;
            }
        }

        for (uint256 i = 0; i < launchpad.participantCount; i++) {
            (address participant, ) = _committedAmountOf[id].at(i);

            if (allocations[id][participant] != launchpad.hardCap) {
                allocations[id][participant] +=
                    remainingCap /
                    (launchpad.participantCount - exceededCount);
            }
        }
    }

    function claim(uint256 id) external whenNotPaused {
        Launchpad storage launchpad = launchpads[id];
        uint256 claimableAmount = allocations[id][msg.sender];
        require(
            claimableAmount > 0,
            "CommittingLaunchpad: zero claimable amount"
        );
        launchpad.tokenContract.transferFrom(
            address(this),
            msg.sender,
            claimableAmount
        );

        payable(msg.sender).transfer(_committedAmountOf[id].get(msg.sender));
    }

    function _daysFromTimestamp(uint256 timestamp)
        private
        pure
        returns (uint256)
    {
        return timestamp / SECOND_PER_DAY;
    }
}

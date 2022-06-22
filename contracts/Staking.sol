// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    uint256 public constant SECONDS_PER_YEAR = 60 * 60 * 24 * 365;
    IERC20 public immutable tokenContract;

    /// @notice unit: tokens per second
    uint256 public immutable rewardRate;
    /// @notice unit: second
    uint256 public immutable cooldownPeriod;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewardOf;
    mapping(address => uint256) public stakersCooldowns;

    uint256 public totalStakedAmount;
    mapping(address => uint256) public stakedAmountOf;

    constructor(
        address _tokenContract,
        uint256 _rewardRate,
        uint256 _cooldownPeriod
    ) {
        tokenContract = IERC20(_tokenContract);
        rewardRate = _rewardRate;
        cooldownPeriod = _cooldownPeriod;
    }

    /// @dev triggered whenever stake, unstake or harvest function is called
    modifier updateRewards(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        rewardOf[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStakedAmount == 0) {
            return 0;
        }

        return
            rewardPerTokenStored +
            (rewardRate * 1e18 * (block.timestamp - lastUpdateTime)) /
            totalStakedAmount;
    }

    function earned(address account) public view returns (uint256) {
        return
            rewardOf[account] +
            (stakedAmountOf[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18;
    }

    function calculateCurrentApy() public view returns (uint256) {}

    function stake(uint256 amount) external updateRewards(msg.sender) {
        totalStakedAmount += amount;
        stakedAmountOf[msg.sender] += amount;

        tokenContract.transferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external updateRewards(msg.sender) {
        uint256 cooldownStartTimestamp = stakersCooldowns[msg.sender];
        require(
            block.timestamp > cooldownStartTimestamp + cooldownPeriod,
            "Staking: insufficient cooldown"
        );

        totalStakedAmount -= amount;
        stakedAmountOf[msg.sender] -= amount;

        tokenContract.transfer(msg.sender, amount);
    }

    function cooldown() external {
        require(
            stakedAmountOf[msg.sender] > 0,
            "Staking: invalid staking balance"
        );

        stakersCooldowns[msg.sender] = block.timestamp;
    }

    function harvest(uint256 amount) external updateRewards(msg.sender) {
        uint256 userReward = rewardOf[msg.sender];
        require(amount <= userReward, "Staking: invalid reward amount");

        rewardOf[msg.sender] -= amount;

        tokenContract.transfer(msg.sender, amount);
    }
}

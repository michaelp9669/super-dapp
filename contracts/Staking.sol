// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Staking {
    IERC20Metadata private _tokenContract;

    /// @notice APY of staking (in percentage)
    uint256 public _rewardRate;
    uint256 public lastUpdateTime;
    uint256 public currentRewardPerToken;
    uint256 private _quota;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _stakingBalances;

    uint256 private _totalStaked;

    modifier updateReward(address account) {
        currentRewardPerToken = rewardPerToken();
        lastUpdateTime = block.timestamp;

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = currentRewardPerToken;
        _;
    }

    constructor(
        address tokenContract,
        uint256 quota,
        uint256 rewardRate
    ) {
        _tokenContract = IERC20Metadata(tokenContract);
        _quota = quota;
        _rewardRate = rewardRate;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalStaked == 0) {
            return currentRewardPerToken;
        }

        return
            currentRewardPerToken +
            ((block.timestamp - lastUpdateTime) *
                _rewardRate *
                _tokenContract.decimals()) /
            _totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return
            ((_stakingBalances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
                _tokenContract.decimals()) + rewards[account];
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        _totalStaked += amount;
        _stakingBalances[msg.sender] += amount;
        _tokenContract.transferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external updateReward(msg.sender) {
        _totalStaked -= amount;
        _stakingBalances[msg.sender] -= amount;
        _tokenContract.transfer(msg.sender, amount);
    }

    function harvest() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        _tokenContract.transfer(msg.sender, reward);
    }

    function remainingQuota() external view returns (uint256) {
        return _quota - _totalStaked;
    }
}

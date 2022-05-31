//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    IERC20 public immutable tokenContract;
    uint256 public constant MAX_STAKING_AMOUNT = 1_000_000 ether;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public stakedAmount;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    constructor(address _tokenContract) {
        tokenContract = IERC20(_tokenContract);
    }

    function rewardPerToken() public view returns (uint256) {
        if (stakedAmount == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) /
                stakedAmount);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((_balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Staking: zero amount not allowed");
        stakedAmount += amount;
        _balances[msg.sender] += amount;
        tokenContract.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        stakedAmount -= amount;
        _balances[msg.sender] -= amount;
        tokenContract.transfer(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        tokenContract.transfer(msg.sender, reward);
    }
}

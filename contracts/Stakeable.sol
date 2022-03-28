// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
* @notice Stakeable is a contract who is ment to be inherited by other contract that wants Staking capabilities
*/
contract Stakeable {


    /**
    * @notice Constructor,since this contract is not ment to be used without inheritance
    * push once to stakeholders for it to work proplerly
     */
    constructor() {
      stakeholders.push();
    }

    struct Stake {
      address user;
      uint256 amount;
      uint256 since;
    }

    struct Stakeholder {
      address user;
      Stake[] addressStakes;
    }

    Stakeholder[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    
    event Staked(address indexed user, uint256 amount, uint256 index, uint256 timestamp);


  function _addStakeholder(address staker) internal returns (uint256) {
    stakeholders.push();
    uint256 userIndex = stakeholders.length  -1;
    stakeholders[userIndex].user = staker;
    stakes[staker] = userIndex;
    return userIndex;
  }

  function _stake(uint256 _amount) internal {
    require(_amount > 0, "Can not stake nothing");

    uint256 index = stakes[msg.sender];
    uint256 timestamp = block.timestamp;

    if (index == 0) {
      index = _addStakeholder(msg.sender);
    }
    stakeholders[index].addressStakes.push(Stake(msg.sender, _amount, timestamp));
    
    emit Staked(msg.sender, _amount, index, timestamp);
  }
}
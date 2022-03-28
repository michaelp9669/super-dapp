//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Stakeable.sol";
import "hardhat/console.sol";


contract SuperAppToken is ERC20, Ownable, Stakeable  {
    constructor() ERC20("SuperApp", "SPA") {
        _mint(msg.sender, 1 * 10**uint(decimals()));
    }

    function stake(uint256 _amount) public {
      require(_amount < balanceOf(msg.sender), "SuperAppToken: Can not stake more than you own");

      _stake(_amount);
      _burn(msg.sender, _amount);
    }
}
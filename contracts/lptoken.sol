// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lp is ERC20, Ownable {






    constructor() ERC20("lptoken", "lp") 
    Ownable(msg.sender)
    {
        
    }

    function mint(address account,uint256 amount) public onlyOwner{
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner
    {
        _burn(account,amount);
    }


}

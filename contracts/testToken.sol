// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract token is ERC20, Ownable {






    constructor() ERC20("token", "A") 
    Ownable(msg.sender)
    {
        _mint(msg.sender, 100000000);
        _mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 100000000);
        _mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 100000000);
        _mint(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, 100000000);
        _mint(0x617F2E2fD72FD9D5503197092aC168c91465E7f2, 100000000);
        
    }

    function mint(address account,uint256 amount) public onlyOwner{
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner
    {
        _burn(account,amount);
    }


}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
 * @title BARIS ATALAY
 * @dev Set & change owner
 */
contract AppleToken is ERC20{
    constructor() ERC20("AppleToken", "AT") {
        // Mint 100 tokens to msg.sender
        // Similar to how
        // 1 dollar = 100 cents
        // 1 token = 1 * (10 ** decimals)
        _mint(_msgSender(), 100 * 10**uint(decimals()));
    }
}
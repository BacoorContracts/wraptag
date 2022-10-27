// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "oz-custom/contracts/oz/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ERC20Test is ERC20Permit {
    constructor()
        ERC20("PaymentToken", "PMT", 18)
        ERC20Permit("PaymentToken")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount * 10**decimals);
    }
}

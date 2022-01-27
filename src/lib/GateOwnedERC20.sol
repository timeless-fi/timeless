// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract GateOwnedERC20 is ERC20 {
    error Error_NotGate();

    address public immutable gate;

    constructor(
        string memory name,
        string memory symbol,
        address gate_
    ) ERC20(name, symbol, 18) {
        gate = gate_;
    }

    function gateMint(address to, uint256 amount) external {
        if (msg.sender != gate) {
            revert Error_NotGate();
        }

        _mint(to, amount);
    }

    function gateBurn(address from, uint256 amount) external {
        if (msg.sender != gate) {
            revert Error_NotGate();
        }

        _burn(from, amount);
    }
}
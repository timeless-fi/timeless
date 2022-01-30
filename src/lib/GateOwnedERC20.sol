// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Gate} from "../Gate.sol";

contract GateOwnedERC20 is ERC20 {
    error Error_NotGate();

    address public immutable gate;
    address public immutable vault;

    constructor(
        string memory name_,
        string memory symbol_,
        address gate_,
        address vault_
    )
        ERC20(
            name_,
            symbol_,
            Gate(gate_).getUnderlyingOfVault(vault_).decimals()
        )
    {
        gate = gate_;
        vault = vault_;
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

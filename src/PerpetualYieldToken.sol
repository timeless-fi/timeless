// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Gate} from "./Gate.sol";
import {GateOwnedERC20} from "./lib/GateOwnedERC20.sol";

contract PerpetualYieldToken is GateOwnedERC20 {
    constructor(address gate_, address vault_)
        GateOwnedERC20("NAME_TBD", "SYMBOL_TBD", gate_, vault_)
    {}

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        Gate(gate).beforePerpetualYieldTokenTransfer(msg.sender, to);

        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        Gate(gate).beforePerpetualYieldTokenTransfer(from, to);

        return super.transferFrom(from, to, amount);
    }
}

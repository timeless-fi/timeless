// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Gate} from "./Gate.sol";
import {BaseERC20} from "./lib/BaseERC20.sol";

/// @title PerpetualYieldToken
/// @author zefram.eth
/// @notice The ERC20 contract representing perpetual yield tokens
contract PerpetualYieldToken is BaseERC20 {
    constructor(address gate_, address vault_)
        BaseERC20(
            Gate(gate_).perpetualYieldTokenName(vault_),
            Gate(gate_).perpetualYieldTokenSymbol(vault_),
            gate_,
            vault_
        )
    {}

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        Gate(gate).beforePerpetualYieldTokenTransfer(msg.sender, to, amount);

        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        Gate(gate).beforePerpetualYieldTokenTransfer(from, to, amount);

        return super.transferFrom(from, to, amount);
    }
}

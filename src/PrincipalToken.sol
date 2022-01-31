// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Gate} from "./Gate.sol";
import {BaseERC20} from "./lib/BaseERC20.sol";

/// @title PrincipalToken
/// @author zefram.eth
/// @notice The ERC20 contract representing principal tokens
contract PrincipalToken is BaseERC20 {
    constructor(address gate_, address vault_)
        BaseERC20(
            Gate(gate_).principalTokenName(vault_),
            Gate(gate_).principalTokenSymbol(vault_),
            gate_,
            vault_
        )
    {}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {GateOwnedERC20} from "./lib/GateOwnedERC20.sol";

contract PrincipalToken is GateOwnedERC20 {
    constructor(address gate_, address vault_)
        GateOwnedERC20("NAME_TBD", "SYMBOL_TBD", gate_, vault_)
    {}
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "./ERC20.sol";

import {Gate} from "../Gate.sol";

/// @title BaseERC20
/// @author zefram.eth
/// @notice The base ERC20 contract used by NegativeYieldToken and PerpetualYieldToken
/// @dev Uses the same number of decimals as the vault's underlying token
contract BaseERC20 is ERC20 {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_NotGate();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    Gate public immutable gate;
    address public immutable vault;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        string memory name_,
        string memory symbol_,
        Gate gate_,
        address vault_
    ) ERC20(name_, symbol_, gate_.getUnderlyingOfVault(vault_).decimals()) {
        gate = gate_;
        vault = vault_;
    }

    /// -----------------------------------------------------------------------
    /// Gate-callable functions
    /// -----------------------------------------------------------------------

    function gateMint(address to, uint256 amount) external virtual {
        if (msg.sender != address(gate)) {
            revert Error_NotGate();
        }

        _mint(to, amount);
    }

    function gateBurn(address from, uint256 amount) external virtual {
        if (msg.sender != address(gate)) {
            revert Error_NotGate();
        }

        _burn(from, amount);
    }

    /// -----------------------------------------------------------------------
    /// ERC20 overrides
    /// -----------------------------------------------------------------------

    function totalSupply() external view virtual override returns (uint256) {
        return gate.yieldTokenTotalSupply(vault);
    }

    /// @dev Update to total supply is omitted since it's done in the Gate instead.
    function _mint(address to, uint256 amount) internal virtual override {
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    /// @dev Update to total supply is omitted since it's done in the Gate instead.
    function _burn(address from, uint256 amount) internal virtual override {
        balanceOf[from] -= amount;

        emit Transfer(from, address(0), amount);
    }
}

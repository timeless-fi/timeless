// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Gate} from "./Gate.sol";
import {ERC20} from "./lib//ERC20.sol";

/// @title YieldToken
/// @author zefram.eth
/// @notice The ERC20 contract representing perpetual yield tokens and negative yield tokens
contract YieldToken is ERC20 {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_NotGate();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    Gate public immutable gate;
    address public immutable vault;
    bool public immutable isPerpetualYieldToken;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        Gate gate_,
        address vault_,
        bool isPerpetualYieldToken_
    )
        ERC20(
            isPerpetualYieldToken_
                ? gate_.perpetualYieldTokenName(vault_)
                : gate_.negativeYieldTokenName(vault_),
            isPerpetualYieldToken_
                ? gate_.perpetualYieldTokenSymbol(vault_)
                : gate_.negativeYieldTokenSymbol(vault_),
            gate_.getUnderlyingOfVault(vault_).decimals()
        )
    {
        gate = gate_;
        vault = vault_;
        isPerpetualYieldToken = isPerpetualYieldToken_;
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
        return Gate(gate).yieldTokenTotalSupply(vault);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        // load balances to save gas
        uint256 fromBalance = balanceOf[msg.sender];
        uint256 toBalance = balanceOf[to];

        if (isPerpetualYieldToken) {
            // call transfer hook
            Gate(gate).beforePerpetualYieldTokenTransfer(
                msg.sender,
                to,
                amount,
                fromBalance,
                toBalance
            );
        }

        // do transfer
        balanceOf[msg.sender] = fromBalance - amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] = toBalance + amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        // load balances to save gas
        uint256 fromBalance = balanceOf[from];
        uint256 toBalance = balanceOf[to];

        if (isPerpetualYieldToken) {
            // call transfer hook
            Gate(gate).beforePerpetualYieldTokenTransfer(
                from,
                to,
                amount,
                fromBalance,
                toBalance
            );
        }

        // update allowance
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;

        // do transfer
        balanceOf[from] = fromBalance - amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] = toBalance + amount;
        }

        emit Transfer(from, to, amount);

        return true;
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

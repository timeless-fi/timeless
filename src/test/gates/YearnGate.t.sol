// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Gate} from "../../Gate.sol";
import {YearnGate} from "../../gates/YearnGate.sol";
import {BaseGateTest} from "../base/BaseGateTest.sol";
import {TestYearnVault} from "../mocks/TestYearnVault.sol";

contract YearnGateTest is BaseGateTest {
    function _deployGate() internal virtual override returns (Gate gate_) {
        return new YearnGate();
    }

    function _deployVault(ERC20 underlying)
        internal
        virtual
        override
        returns (address vault)
    {
        return address(new TestYearnVault(underlying));
    }

    function _depositInVault(address vault, uint256 underlyingAmount)
        internal
        virtual
        override
        returns (uint256)
    {
        return TestYearnVault(vault).deposit(underlyingAmount);
    }

    function _getExpectedNYTName()
        internal
        virtual
        override
        returns (string memory)
    {
        return "Timeless TestYearnVault Negative Yield Token";
    }

    function _getExpectedNYTSymbol()
        internal
        virtual
        override
        returns (string memory)
    {
        return unicode"∞-yTEST-NYT";
    }

    function _getExpectedPYTName()
        internal
        virtual
        override
        returns (string memory)
    {
        return "Timeless TestYearnVault Perpetual Yield Token";
    }

    function _getExpectedPYTSymbol()
        internal
        virtual
        override
        returns (string memory)
    {
        return unicode"∞-yTEST-PYT";
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {Factory} from "../Factory.sol";
import {ERC20Gate} from "./ERC20Gate.sol";
import {YearnVault} from "../external/YearnVault.sol";

/// @title YearnGate
/// @author zefram.eth
/// @notice The Gate implementation for Yearn vaults
contract YearnGate is ERC20Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    constructor(Factory factory_) ERC20Gate(factory_) {}

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    /// @inheritdoc Gate
    function getUnderlyingOfVault(address vault)
        public
        view
        virtual
        override
        returns (ERC20)
    {
        return ERC20(YearnVault(vault).token());
    }

    /// @inheritdoc Gate
    function getPricePerVaultShare(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return YearnVault(vault).pricePerShare();
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    /// @inheritdoc Gate
    function _depositIntoVault(
        ERC20 underlying,
        uint256 underlyingAmount,
        address vault
    ) internal virtual override {
        if (underlying.allowance(address(this), vault) < underlyingAmount) {
            underlying.safeApprove(vault, type(uint256).max);
        }

        YearnVault(vault).deposit(underlyingAmount);
    }

    /// @inheritdoc Gate
    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint8 underlyingDecimals,
        uint256 pricePerVaultShare,
        bool checkBalance
    ) internal virtual override returns (uint256 withdrawnUnderlyingAmount) {
        uint256 shareAmount = _underlyingAmountToVaultSharesAmount(
            underlyingAmount,
            underlyingDecimals,
            pricePerVaultShare
        );

        if (checkBalance) {
            uint256 shareBalance = getVaultShareBalance(vault);
            if (shareAmount > shareBalance) {
                // rounding error, withdraw entire balance
                shareAmount = shareBalance;
            }
        }

        withdrawnUnderlyingAmount = YearnVault(vault).withdraw(
            shareAmount,
            recipient
        );
    }
}

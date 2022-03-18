// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {Factory} from "../Factory.sol";
import {FullMath} from "../lib/FullMath.sol";

/// @title ERC4626Gate
/// @author zefram.eth
/// @notice The Gate implementation for ERC4626 vaults
contract ERC4626Gate is Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Initialization
    /// -----------------------------------------------------------------------

    constructor(Factory factory_) Gate(factory_) {}

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
        return ERC4626(vault).asset();
    }

    /// @inheritdoc Gate
    function getPricePerVaultShare(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        ERC4626 erc4626Vault = ERC4626(vault);
        return erc4626Vault.convertToAssets(10**erc4626Vault.decimals());
    }

    function getVaultShareBalance(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return ERC4626(vault).balanceOf(address(this));
    }

    /// @inheritdoc Gate
    function vaultSharesIsERC20() public pure virtual override returns (bool) {
        return true;
    }

    /// @inheritdoc Gate
    function negativeYieldTokenName(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "Timeless ",
                    ERC4626(vault).name(),
                    " Negative Yield Token"
                )
            );
    }

    /// @inheritdoc Gate
    function negativeYieldTokenSymbol(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(unicode"∞-", ERC4626(vault).symbol(), "-NYT")
            );
    }

    /// @inheritdoc Gate
    function perpetualYieldTokenName(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "Timeless ",
                    ERC4626(vault).name(),
                    " Perpetual Yield Token"
                )
            );
    }

    /// @inheritdoc Gate
    function perpetualYieldTokenSymbol(address vault)
        external
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(unicode"∞-", ERC4626(vault).symbol(), "-PYT")
            );
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

        ERC4626(vault).deposit(underlyingAmount, address(this));
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

        withdrawnUnderlyingAmount = ERC4626(vault).redeem(
            shareAmount,
            recipient,
            address(this)
        );
    }
}

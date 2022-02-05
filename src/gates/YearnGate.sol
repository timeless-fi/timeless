// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {FullMath} from "../lib/FullMath.sol";
import {YearnVault} from "../external/YearnVault.sol";
import {PerpetualYieldToken} from "../PerpetualYieldToken.sol";

/// @title YearnGate
/// @author zefram.eth
/// @notice The Gate implementation for Yearn vaults
contract YearnGate is Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

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

    function getVaultShareBalance(address vault)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return YearnVault(vault).balanceOf(address(this));
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
                    YearnVault(vault).name(),
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
                abi.encodePacked(
                    unicode"∞-",
                    YearnVault(vault).symbol(),
                    "-NYT"
                )
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
                    YearnVault(vault).name(),
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
                abi.encodePacked(
                    unicode"∞-",
                    YearnVault(vault).symbol(),
                    "-PYT"
                )
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

        YearnVault(vault).deposit(underlyingAmount);
    }

    /// @inheritdoc Gate
    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal virtual override {
        uint256 shareAmount = FullMath.mulDiv(
            underlyingAmount,
            10**underlyingDecimals,
            getPricePerVaultShare(vault)
        );
        YearnVault(vault).withdraw(shareAmount, recipient);
    }

    /// @inheritdoc Gate
    function _vaultSharesAmountToUnderlyingAmount(
        address vault,
        uint256 vaultSharesAmount,
        uint8 underlyingDecimals
    ) internal view virtual override returns (uint256) {
        return
            FullMath.mulDiv(
                vaultSharesAmount,
                getPricePerVaultShare(vault),
                10**underlyingDecimals
            );
    }

    /// @inheritdoc Gate
    function _underlyingAmountToVaultSharesAmount(
        address vault,
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal view virtual override returns (uint256) {
        return
            FullMath.mulDiv(
                underlyingAmount,
                10**underlyingDecimals,
                getPricePerVaultShare(vault)
            );
    }

    /// @inheritdoc Gate
    function _computeYieldPerToken(
        address vault,
        PerpetualYieldToken pyt,
        uint256 updatedPricePerVaultShare,
        uint8 underlyingDecimals
    ) internal view virtual override returns (uint256) {
        uint256 pytTotalSupply = pyt.totalSupply();
        if (pytTotalSupply == 0) {
            return yieldPerTokenStored[vault];
        }
        uint256 pricePerVaultShareStored_ = pricePerVaultShareStored[vault];
        if (updatedPricePerVaultShare <= pricePerVaultShareStored_) {
            // rounding error in vault share or no yield accrued
            return yieldPerTokenStored[vault];
        }
        uint256 underlyingPrecision = 10**underlyingDecimals;
        uint256 newYieldAccrued;
        unchecked {
            // can't underflow since we know updatedPricePerVaultShare > pricePerVaultShareStored_
            newYieldAccrued = FullMath.mulDiv(
                updatedPricePerVaultShare - pricePerVaultShareStored_,
                getVaultShareBalance(vault),
                underlyingPrecision
            );
        }
        return
            yieldPerTokenStored[vault] +
            FullMath.mulDiv(newYieldAccrued, PRECISION, pytTotalSupply);
    }
}

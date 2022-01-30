// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {FullMath} from "../lib/FullMath.sol";
import {YearnVault} from "../external/YearnVault.sol";
import {PerpetualYieldToken} from "../PerpetualYieldToken.sol";

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
    function _vaultSharesAmountToTokenPairAmount(
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
        uint256 newYieldAccrued = FullMath.mulDiv(
            (updatedPricePerVaultShare - pricePerVaultShareStored[vault]),
            getVaultShareBalance(vault),
            10**underlyingDecimals
        );
        return
            yieldPerTokenStored[vault] +
            FullMath.mulDiv(newYieldAccrued, PRECISION, pytTotalSupply);
    }
}

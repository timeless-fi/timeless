// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Gate} from "../Gate.sol";
import {FullMath} from "../lib/FullMath.sol";
import {YearnVault} from "../external/YearnVault.sol";

contract YearnGate is Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Internal virtual functions
    /// -----------------------------------------------------------------------

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

    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal virtual override {
        uint256 shareAmount = FullMath.mulDiv(
            underlyingAmount,
            10**underlyingDecimals,
            YearnVault(vault).pricePerShare()
        );
        YearnVault(vault).withdraw(shareAmount, recipient);
    }

    function _vaultSharesAmountToTokenPairAmount(
        address vault,
        uint256 vaultSharesAmount
    ) internal view virtual override returns (uint256) {
        return
            FullMath.mulDiv(
                vaultSharesAmount,
                YearnVault(vault).pricePerShare(),
                10**YearnVault(vault).decimals()
            );
    }
}

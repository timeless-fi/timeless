// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {PrincipalToken} from "./PrincipalToken.sol";
import {PerpetualYieldToken} from "./PerpetualYieldToken.sol";

abstract contract Gate {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_TokenPairNotDeployed();

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    function enterWithUnderlying(
        address recipient,
        ERC20 underlying,
        uint256 underlyingAmount,
        address vault
    ) external virtual returns (uint256 mintAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pt).code.length == 0) {
            // token pair hasn't been deployed yet
            // do the deployment now
            // only need to check pt since pt and pyt are always deployed in pairs
            deployTokenPairForVault(vault);
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // mint PTs and PYTs
        mintAmount = _underlyingAmountToTokenPairAmount(
            underlyingAmount,
            underlying.decimals()
        );
        pt.gateMint(recipient, mintAmount);
        pyt.gateMint(recipient, mintAmount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        // transfer underlying from msg.sender to address(this)
        underlying.safeTransferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );

        // deposit underlying into vault
        _depositIntoVault(underlying, underlyingAmount, vault);
    }

    function enterWithVaultShares(
        address recipient,
        address vault,
        uint256 vaultSharesAmount
    ) external virtual returns (uint256 mintAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pt).code.length == 0) {
            // token pair hasn't been deployed yet
            // do the deployment now
            // only need to check pt since pt and pyt are always deployed in pairs
            deployTokenPairForVault(vault);
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // mint PTs and PYTs
        mintAmount = _vaultSharesAmountToTokenPairAmount(
            vault,
            vaultSharesAmount
        );
        pt.gateMint(recipient, mintAmount);
        pyt.gateMint(recipient, mintAmount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        // transfer vault tokens from msg.sender to address(this)
        ERC20(vault).safeTransferFrom(
            msg.sender,
            address(this),
            vaultSharesAmount
        );
    }

    function exitToUnderlying(
        address recipient,
        ERC20 underlying,
        uint256 underlyingAmount,
        address vault
    ) external virtual returns (uint256 burnAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pt).code.length == 0) {
            revert Error_TokenPairNotDeployed();
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // burn PTs and PYTs
        uint8 underlyingDecimals = underlying.decimals();
        burnAmount = _underlyingAmountToTokenPairAmount(
            underlyingAmount,
            underlyingDecimals
        );
        pt.gateBurn(msg.sender, burnAmount);
        pyt.gateBurn(msg.sender, burnAmount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        // withdraw underlying from vault to recipient
        _withdrawFromVault(
            recipient,
            vault,
            underlyingAmount,
            underlyingDecimals
        );
    }

    function exitToVaultShares(
        address recipient,
        address vault,
        uint256 vaultSharesAmount
    ) external virtual returns (uint256 burnAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pt).code.length == 0) {
            revert Error_TokenPairNotDeployed();
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // burn PTs and PYTs
        burnAmount = _vaultSharesAmountToTokenPairAmount(
            vault,
            vaultSharesAmount
        );
        pt.gateBurn(msg.sender, burnAmount);
        pyt.gateBurn(msg.sender, burnAmount);

        /// -----------------------------------------------------------------------
        /// Effects
        /// -----------------------------------------------------------------------

        // transfer vault tokens to recipient
        ERC20(vault).safeTransfer(recipient, vaultSharesAmount);
    }

    function deployTokenPairForVault(address vault)
        public
        virtual
        returns (PrincipalToken pt, PerpetualYieldToken pyt)
    {
        // Use the CREATE2 opcode to deploy new PrincipalToken and PerpetualYieldToken contracts.
        // This will revert if the contracts have already been deployed,
        // as the salt would be the same and we can't deploy with it twice.
        pt = new PrincipalToken{salt: address(vault).fillLast12Bytes()}(
            address(this)
        );
        pyt = new PerpetualYieldToken{salt: address(vault).fillLast12Bytes()}(
            address(this)
        );
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function getPrincipalTokenForVault(address vault)
        public
        virtual
        returns (PrincipalToken)
    {
        return
            PrincipalToken(
                keccak256(
                    abi.encodePacked(
                        // Prefix:
                        bytes1(0xFF),
                        // Creator:
                        address(this),
                        // Salt:
                        address(vault).fillLast12Bytes(),
                        // Bytecode hash:
                        keccak256(
                            abi.encodePacked(
                                // Deployment bytecode:
                                type(PrincipalToken).creationCode,
                                // Constructor arguments:
                                abi.encode(address(this))
                            )
                        )
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
            );
    }

    function getPerpetualYieldTokenForVault(address vault)
        public
        virtual
        returns (PerpetualYieldToken)
    {
        return
            PerpetualYieldToken(
                keccak256(
                    abi.encodePacked(
                        // Prefix:
                        bytes1(0xFF),
                        // Creator:
                        address(this),
                        // Salt:
                        address(vault).fillLast12Bytes(),
                        // Bytecode hash:
                        keccak256(
                            abi.encodePacked(
                                // Deployment bytecode:
                                type(PerpetualYieldToken).creationCode,
                                // Constructor arguments:
                                abi.encode(address(this))
                            )
                        )
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
            );
    }

    /// -----------------------------------------------------------------------
    /// Internal virtual functions
    /// -----------------------------------------------------------------------

    function _depositIntoVault(
        ERC20 underlying,
        uint256 underlyingAmount,
        address vault
    ) internal virtual;

    function _withdrawFromVault(
        address recipient,
        address vault,
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal virtual;

    function _vaultSharesAmountToTokenPairAmount(
        address vault,
        uint256 vaultSharesAmount
    ) internal view virtual returns (uint256);

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    function _underlyingAmountToTokenPairAmount(
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal pure returns (uint256) {
        if (underlyingDecimals == 18) {
            return underlyingAmount;
        } else if (underlyingDecimals < 18) {
            return underlyingAmount * (10**(18 - underlyingDecimals));
        } else {
            return underlyingAmount / (10**(underlyingDecimals - 18));
        }
    }
}

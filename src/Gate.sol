// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";

import {FullMath} from "./lib/FullMath.sol";
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

    error Error_VaultSharesNotERC20();
    error Error_TokenPairNotDeployed();
    error Error_SenderNotPerpetualYieldToken();

    /// -----------------------------------------------------------------------
    /// Constants
    /// -----------------------------------------------------------------------

    uint256 internal constant PRECISION = 10**18;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice vault => value
    mapping(address => uint256) public pricePerVaultShareStored;

    /// @notice vault => value
    mapping(address => uint256) public yieldPerTokenStored;

    /// @notice vault => user => value
    mapping(address => mapping(address => uint256))
        public userYieldPerTokenStored;

    /// @notice vault => user => value
    mapping(address => mapping(address => uint256)) public userAccruedYield;

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    function enterWithUnderlying(
        address recipient,
        address vault,
        uint256 underlyingAmount
    ) external virtual returns (uint256 mintAmount) {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        if (address(pt).code.length == 0) {
            // token pair hasn't been deployed yet
            // do the deployment now
            // only need to check pt since pt and pyt are always deployed in pairs
            deployTokenPairForVault(vault);
        }
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        ERC20 underlying = getUnderlyingOfVault(vault);

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue yield
        _accrueYield(vault, pyt, msg.sender);

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

        // only supported if vault shares are ERC20
        if (!vaultSharesIsERC20()) {
            revert Error_VaultSharesNotERC20();
        }

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

        // accrue yield
        _accrueYield(vault, pyt, msg.sender);

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
        address vault,
        uint256 underlyingAmount
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

        // accrue yield
        _accrueYield(vault, pyt, msg.sender);

        // burn PTs and PYTs
        uint8 underlyingDecimals = getUnderlyingOfVault(vault).decimals();
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

        // only supported if vault shares are ERC20
        if (!vaultSharesIsERC20()) {
            revert Error_VaultSharesNotERC20();
        }

        PrincipalToken pt = getPrincipalTokenForVault(vault);
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pt).code.length == 0) {
            revert Error_TokenPairNotDeployed();
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue yield
        _accrueYield(vault, pyt, msg.sender);

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
        pt = new PrincipalToken{salt: vault.fillLast12Bytes()}(
            address(this),
            vault
        );
        pyt = new PerpetualYieldToken{salt: vault.fillLast12Bytes()}(
            address(this),
            vault
        );
    }

    function claimYield(address recipient, address vault)
        external
        virtual
        returns (uint256 yieldAmount)
    {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (address(pyt).code.length == 0) {
            revert Error_TokenPairNotDeployed();
        }

        // accrue yield
        uint256 updatedPricePerVaultShare = getPricePerVaultShare(vault);
        pricePerVaultShareStored[vault] = updatedPricePerVaultShare;
        uint256 updatedYieldPerToken = _computeYieldPerToken(
            vault,
            pyt,
            updatedPricePerVaultShare
        );
        yieldPerTokenStored[vault] = updatedYieldPerToken;
        yieldAmount = _getClaimableYieldAmount(
            vault,
            pyt,
            msg.sender,
            updatedYieldPerToken
        );
        userYieldPerTokenStored[vault][msg.sender] = updatedYieldPerToken;

        // withdraw yield
        if (yieldAmount > 0) {
            userAccruedYield[vault][msg.sender] = 0;

            _withdrawFromVault(
                recipient,
                vault,
                yieldAmount,
                getUnderlyingOfVault(vault).decimals()
            );
        }
    }

    /// -----------------------------------------------------------------------
    /// Getters
    /// -----------------------------------------------------------------------

    function getPrincipalTokenForVault(address vault)
        public
        view
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
                                abi.encode(address(this), vault)
                            )
                        )
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
            );
    }

    function getPerpetualYieldTokenForVault(address vault)
        public
        view
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
                                abi.encode(address(this), vault)
                            )
                        )
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
            );
    }

    function getClaimableYieldAmount(address vault, address user)
        external
        view
        virtual
        returns (uint256)
    {
        return
            _getClaimableYieldAmount(
                vault,
                getPerpetualYieldTokenForVault(vault),
                user,
                yieldPerTokenStored[vault]
            );
    }

    function computeYieldPerToken(address vault)
        external
        view
        virtual
        returns (uint256)
    {
        return
            _computeYieldPerToken(
                vault,
                getPerpetualYieldTokenForVault(vault),
                pricePerVaultShareStored[vault]
            );
    }

    function getUnderlyingOfVault(address vault)
        public
        view
        virtual
        returns (ERC20);

    function getPricePerVaultShare(address vault)
        public
        view
        virtual
        returns (uint256);

    function vaultSharesIsERC20() public pure virtual returns (bool);

    /// -----------------------------------------------------------------------
    /// PYT transfer hooks
    /// -----------------------------------------------------------------------

    function beforePerpetualYieldTokenTransfer(address from, address to)
        external
        virtual
    {
        /// -----------------------------------------------------------------------
        /// Validation
        /// -----------------------------------------------------------------------

        address vault = PerpetualYieldToken(msg.sender).vault();
        PerpetualYieldToken pyt = getPerpetualYieldTokenForVault(vault);
        if (msg.sender != address(pyt)) {
            revert Error_SenderNotPerpetualYieldToken();
        }

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // accrue yield
        uint256 updatedPricePerVaultShare = getPricePerVaultShare(vault);
        pricePerVaultShareStored[vault] = updatedPricePerVaultShare;
        uint256 updatedYieldPerToken = _computeYieldPerToken(
            vault,
            pyt,
            updatedPricePerVaultShare
        );
        yieldPerTokenStored[vault] = updatedYieldPerToken;

        // we know the from account must have held PYTs before
        // so we will always accrue the yield earned by the from account
        userAccruedYield[vault][from] = _getClaimableYieldAmount(
            vault,
            pyt,
            from,
            updatedYieldPerToken
        );
        userYieldPerTokenStored[vault][from] = updatedYieldPerToken;

        // the to account might not have held PYTs before
        // we only accrue yield if they have
        if (userYieldPerTokenStored[vault][to] != 0) {
            // to account has held PYTs before
            userAccruedYield[vault][to] = _getClaimableYieldAmount(
                vault,
                pyt,
                to,
                updatedYieldPerToken
            );
        }
        userYieldPerTokenStored[vault][to] = updatedYieldPerToken;
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    function _accrueYield(
        address vault,
        PerpetualYieldToken pyt,
        address user
    ) internal virtual {
        uint256 updatedPricePerVaultShare = getPricePerVaultShare(vault);
        pricePerVaultShareStored[vault] = updatedPricePerVaultShare;
        uint256 updatedYieldPerToken = _computeYieldPerToken(
            vault,
            pyt,
            updatedPricePerVaultShare
        );
        yieldPerTokenStored[vault] = updatedYieldPerToken;
        userAccruedYield[vault][user] = _getClaimableYieldAmount(
            vault,
            pyt,
            user,
            updatedYieldPerToken
        );
        userYieldPerTokenStored[vault][user] = updatedYieldPerToken;
    }

    function _underlyingAmountToTokenPairAmount(
        uint256 underlyingAmount,
        uint8 underlyingDecimals
    ) internal pure virtual returns (uint256) {
        if (underlyingDecimals == 18) {
            return underlyingAmount;
        } else if (underlyingDecimals < 18) {
            return underlyingAmount * (10**(18 - underlyingDecimals));
        } else {
            return underlyingAmount / (10**(underlyingDecimals - 18));
        }
    }

    function _getClaimableYieldAmount(
        address vault,
        PerpetualYieldToken pyt,
        address user,
        uint256 yieldPerTokenStored_
    ) internal view virtual returns (uint256) {
        return
            FullMath.mulDiv(
                pyt.balanceOf(user),
                yieldPerTokenStored_ - userYieldPerTokenStored[vault][user],
                PRECISION
            ) + userAccruedYield[vault][user];
    }

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

    function _computeYieldPerToken(
        address vault,
        PerpetualYieldToken pyt,
        uint256 pricePerVaultShareStored_
    ) internal view virtual returns (uint256);
}

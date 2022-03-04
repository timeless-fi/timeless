// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {Gate} from "./Gate.sol";
import {Ownable} from "./lib/Ownable.sol";
import {YieldToken} from "./YieldToken.sol";

contract Factory is Ownable {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Error_ProtocolFeeRecipientIsZero();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SetProtocolFee(ProtocolFeeInfo protocolFeeInfo_);
    event DeployYieldTokenPair(
        Gate indexed gate,
        address indexed vault,
        YieldToken nyt,
        YieldToken pyt
    );

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    struct ProtocolFeeInfo {
        uint8 fee; // each increment represents 0.1%, so max is 25.5%
        address recipient;
    }
    /// @notice The protocol fee and the fee recipient address.
    ProtocolFeeInfo public protocolFeeInfo;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address initialOwner, ProtocolFeeInfo memory protocolFeeInfo_) {
        _transferOwnership(initialOwner);

        if (
            protocolFeeInfo_.fee != 0 &&
            protocolFeeInfo_.recipient == address(0)
        ) {
            revert Error_ProtocolFeeRecipientIsZero();
        }
        protocolFeeInfo = protocolFeeInfo_;
        emit SetProtocolFee(protocolFeeInfo_);
    }

    /// -----------------------------------------------------------------------
    /// User actions
    /// -----------------------------------------------------------------------

    /// @notice Deploys the NegativeYieldToken and PerpetualYieldToken associated with a vault.
    /// @dev Will revert if they have already been deployed.
    /// @param gate The gate that will use the NYT and PYT
    /// @param vault The vault to deploy NYT and PYT for
    /// @return nyt The deployed NegativeYieldToken
    /// @return pyt The deployed PerpetualYieldToken
    function deployYieldTokenPair(Gate gate, address vault)
        public
        virtual
        returns (YieldToken nyt, YieldToken pyt)
    {
        // Use the CREATE2 opcode to deploy new NegativeYieldToken and PerpetualYieldToken contracts.
        // This will revert if the contracts have already been deployed,
        // as the salt & bytecode hash would be the same and we can't deploy with it twice.
        nyt = new YieldToken{salt: bytes32(0)}(gate, vault, false);
        pyt = new YieldToken{salt: bytes32(0)}(gate, vault, true);

        emit DeployYieldTokenPair(gate, vault, nyt, pyt);
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    /// @notice Updates the protocol fee and/or the protocol fee recipient.
    /// Only callable by the owner.
    /// @param protocolFeeInfo_ The new protocol fee info
    function ownerSetProtocolFee(ProtocolFeeInfo calldata protocolFeeInfo_)
        external
        onlyOwner
    {
        if (
            protocolFeeInfo_.fee != 0 &&
            protocolFeeInfo_.recipient == address(0)
        ) {
            revert Error_ProtocolFeeRecipientIsZero();
        }
        protocolFeeInfo = protocolFeeInfo_;

        emit SetProtocolFee(protocolFeeInfo_);
    }
}

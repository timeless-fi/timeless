// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract TestYearnVault is ERC20 {
    using FixedPointMathLib for uint256;

    ERC20 public immutable token;
    uint256 public immutable BASE_UNIT;

    constructor(ERC20 token_)
        ERC20("TestYearnVault", "yTEST", token_.decimals())
    {
        token = token_;
        BASE_UNIT = 10**token_.decimals();
    }

    function deposit(uint256 tokenAmount) public returns (uint256 shareAmount) {
        uint256 sharePrice = pricePerShare();
        shareAmount = tokenAmount.fdiv(sharePrice, BASE_UNIT);
        _mint(msg.sender, shareAmount);

        token.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function withdraw(uint256 sharesAmount)
        public
        returns (uint256 underlyingAmount)
    {
        uint256 sharePrice = pricePerShare();
        underlyingAmount = sharesAmount.fmul(sharePrice, BASE_UNIT);
        _burn(msg.sender, sharesAmount);

        token.transfer(msg.sender, underlyingAmount);
    }

    function withdraw(uint256 sharesAmount, address recipient)
        public
        returns (uint256 underlyingAmount)
    {
        uint256 sharePrice = pricePerShare();
        underlyingAmount = sharesAmount.fmul(sharePrice, BASE_UNIT);
        _burn(msg.sender, sharesAmount);

        token.transfer(recipient, underlyingAmount);
    }

    function pricePerShare() public view returns (uint256) {
        uint256 totalSupply_ = totalSupply;
        if (totalSupply_ == 0) {
            return BASE_UNIT;
        }
        return token.balanceOf(address(this)).fdiv(totalSupply_, BASE_UNIT);
    }
}

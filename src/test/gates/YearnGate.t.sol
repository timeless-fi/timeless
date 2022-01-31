// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {BaseTest, console} from "../base/BaseTest.sol";

import {FullMath} from "../../lib/FullMath.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {YearnGate} from "../../gates/YearnGate.sol";
import {PrincipalToken} from "../../PrincipalToken.sol";
import {TestYearnVault} from "../mocks/TestYearnVault.sol";
import {PerpetualYieldToken} from "../../PerpetualYieldToken.sol";

contract YearnGateTest is BaseTest {
    /// -----------------------------------------------------------------------
    /// Global state
    /// -----------------------------------------------------------------------

    YearnGate internal gate;
    address internal constant tester = address(0x69);
    address internal constant recipient = address(0xbeef);
    address internal constant initialDepositor = address(0x420);

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    function setUp() public {
        gate = new YearnGate();
    }

    /// -----------------------------------------------------------------------
    /// User action tests
    /// -----------------------------------------------------------------------

    function test_enterWithUnderlying(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        if (underlyingDecimals > 18) {
            // crazy stupid token, why would you do this
            underlyingDecimals %= 18;
        }

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        uint256 beforeVaultUnderlyingBalance = underlying.balanceOf(
            address(vault)
        );
        uint256 mintAmount = gate.enterWithUnderlying(
            recipient,
            address(vault),
            underlyingAmount
        );

        // check balances
        // underlying transferred from tester to vault
        assertEqDecimal(underlying.balanceOf(tester), 0, underlyingDecimals);
        assertEqDecimal(
            underlying.balanceOf(address(vault)) - beforeVaultUnderlyingBalance,
            underlyingAmount,
            underlyingDecimals
        );
        // recipient received PT and PYT
        PrincipalToken pt = gate.getPrincipalTokenForVault(address(vault));
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        assertEqDecimal(
            pt.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals
        );
        assertEqDecimal(
            pyt.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals
        );
        assertEqDecimal(mintAmount, underlyingAmount, underlyingDecimals);
    }

    function test_enterWithVaultShares(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        if (underlyingDecimals > 18) {
            // crazy stupid token, why would you do this
            underlyingDecimals %= 18;
        }

        if (initialUnderlyingAmount == 0 && initialYieldAmount != 0) {
            // don't give tester free yield
            initialUnderlyingAmount = initialYieldAmount;
        }

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying and enter vault
        underlying.mint(tester, underlyingAmount);
        uint256 vaultSharesAmount = vault.deposit(underlyingAmount);

        // enter
        vault.approve(address(gate), type(uint256).max);
        uint256 mintAmount = gate.enterWithVaultShares(
            recipient,
            address(vault),
            vaultSharesAmount
        );

        // check balances
        // vault shares transferred from tester to gate
        assertEqDecimal(vault.balanceOf(tester), 0, underlyingDecimals);
        assertEqDecimal(
            vault.balanceOf(address(gate)),
            vaultSharesAmount,
            underlyingDecimals
        );
        // recipient received PT and PYT
        PrincipalToken pt = gate.getPrincipalTokenForVault(address(vault));
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        uint256 epsilonInv = 10**53;
        assertEqDecimalEpsilonBelow(
            pt.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            pyt.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            mintAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_exitToUnderlying(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        if (underlyingDecimals > 18) {
            // crazy stupid token, why would you do this
            underlyingDecimals %= 18;
        }

        if (initialUnderlyingAmount == 0 && initialYieldAmount != 0) {
            // don't give tester free yield
            initialUnderlyingAmount = initialYieldAmount;
        }

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, address(vault), underlyingAmount);

        // mint additional yield to the vault
        underlying.mint(address(vault), additionalYieldAmount);

        // exit
        uint256 burnAmount = gate.exitToUnderlying(
            recipient,
            address(vault),
            underlyingAmount
        );

        // check balances
        uint256 epsilonInv = 10**52;
        // underlying transferred to tester
        assertEqDecimalEpsilonBelow(
            underlying.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        // recipient burnt PT and PYT
        PrincipalToken pt = gate.getPrincipalTokenForVault(address(vault));
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        assertEqDecimalEpsilonBelow(
            pt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            pyt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            burnAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_exitToVaultShares(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        if (underlyingDecimals > 18) {
            // crazy stupid token, why would you do this
            underlyingDecimals %= 18;
        }

        if (initialUnderlyingAmount == 0 && initialYieldAmount != 0) {
            // don't give tester free yield
            initialUnderlyingAmount = initialYieldAmount;
        }

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, address(vault), underlyingAmount);

        // mint additional yield to the vault
        underlying.mint(address(vault), additionalYieldAmount);

        // exit
        uint256 vaultSharesAmount = FullMath.mulDiv(
            underlyingAmount,
            10**underlyingDecimals,
            vault.pricePerShare()
        );
        uint256 burnAmount = gate.exitToVaultShares(
            recipient,
            address(vault),
            vaultSharesAmount
        );

        // check balances
        uint256 epsilonInv = 10**52;
        // vault shares transferred to tester
        assertEqDecimalEpsilonBelow(
            vault.balanceOf(recipient),
            vaultSharesAmount,
            underlyingDecimals,
            epsilonInv
        );
        // recipient burnt PT and PYT
        PrincipalToken pt = gate.getPrincipalTokenForVault(address(vault));
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        assertEqDecimalEpsilonBelow(
            pt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            pyt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            burnAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_deployTokenPairForVault(uint8 underlyingDecimals) public {
        if (underlyingDecimals > 18) {
            // crazy stupid token, why would you do this
            underlyingDecimals %= 18;
        }

        TestERC20 underlying = new TestERC20(underlyingDecimals);
        TestYearnVault vault = new TestYearnVault(underlying);
        (PrincipalToken pt, PerpetualYieldToken pyt) = gate
            .deployTokenPairForVault(address(vault));

        assertEq(
            address(gate.getPrincipalTokenForVault(address(vault))),
            address(pt)
        );
        assertEq(
            address(gate.getPerpetualYieldTokenForVault(address(vault))),
            address(pyt)
        );
        assertEq(pt.decimals(), underlyingDecimals);
        assertEq(pyt.decimals(), underlyingDecimals);
        assertEq(pt.totalSupply(), 0);
        assertEq(pyt.totalSupply(), 0);
    }

    function test_claimYield() public {}

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    function _setUpVault(
        uint8 underlyingDecimals,
        uint256 initialUnderlyingAmount,
        uint256 initialYieldAmount
    ) internal returns (TestERC20 underlying, TestYearnVault vault) {
        // setup contracts
        underlying = new TestERC20(underlyingDecimals);
        vault = new TestYearnVault(underlying);
        underlying.approve(address(gate), type(uint256).max);
        underlying.approve(address(vault), type(uint256).max);
        gate.deployTokenPairForVault(address(vault));

        // initialize deposits & yield
        underlying.mint(initialDepositor, initialUnderlyingAmount);
        vm.prank(initialDepositor);
        underlying.approve(address(vault), type(uint256).max);
        vm.prank(initialDepositor);
        vault.deposit(initialUnderlyingAmount);
        underlying.mint(address(vault), initialYieldAmount);
    }
}

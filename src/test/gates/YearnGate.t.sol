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
    address internal constant tester1 = address(0xabcd);
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

        // bound between 0 and 18
        underlyingDecimals %= 19;

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

        // bound between 0 and 18
        underlyingDecimals %= 19;

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

        // bound between 0 and 18
        underlyingDecimals %= 19;

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

        // bound between 0 and 18
        underlyingDecimals %= 19;

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
        // bound between 0 and 18
        underlyingDecimals %= 19;

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
        assertEq(pt.name(), "Timeless TestYearnVault Principal Token");
        assertEq(pyt.name(), "Timeless TestYearnVault Perpetual Yield Token");
        assertEq(pt.symbol(), unicode"∞-yTEST-PT");
        assertEq(pyt.symbol(), unicode"∞-yTEST-PYT");
        assertEq(pt.decimals(), underlyingDecimals);
        assertEq(pyt.decimals(), underlyingDecimals);
        assertEq(pt.totalSupply(), 0);
        assertEq(pyt.totalSupply(), 0);
    }

    function test_claimYield(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        // bound between 0 and 18
        underlyingDecimals %= 19;

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
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(address(vault))
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }
        uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
            address(vault)
        );
        underlying.mint(address(vault), additionalYieldAmount);
        uint256 afterPricePerVaultShare = gate.getPricePerVaultShare(
            address(vault)
        );

        // claim yield
        uint256 claimedYield = gate.claimYield(recipient, address(vault));

        // check received yield
        uint256 expectedYield = FullMath.mulDiv(
            underlyingAmount,
            afterPricePerVaultShare - beforePricePerVaultShare,
            beforePricePerVaultShare
        );
        uint256 epsilonInv = 10**10;
        assertEqDecimalEpsilonBelow(
            claimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            underlying.balanceOf(recipient),
            claimedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_transferPYT_toUninitializedAccount(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount,
        uint8 pytTransferPercent
    ) public {
        vm.startPrank(tester);

        // bound between 3 and 18
        underlyingDecimals %= 16;
        underlyingDecimals += 3;

        // bound the initial yield below 100x the initial underlying
        if (initialUnderlyingAmount != 0) {
            initialYieldAmount = uint192(
                initialYieldAmount % (uint256(initialUnderlyingAmount) * 100)
            );
        } else {
            initialYieldAmount = 0;
        }

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

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
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(address(vault))
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                address(vault)
            );
            underlying.mint(address(vault), additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(address(vault)) -
                    beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(address(vault)).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYield(recipient, address(vault));

        // tester should've received all the yield
        uint256 epsilonInv = 10**(underlyingDecimals - 3);
        assertEqDecimalEpsilonBelow(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should have received 0
        epsilonInv = 10**(underlyingDecimals - 2);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertLeDecimal(
            gate.claimYield(tester1, address(vault)),
            testerClaimedYield / epsilonInv,
            underlyingDecimals
        );
    }

    function test_transferPYT_toInitializedAccount(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount,
        uint8 pytTransferPercent
    ) public {
        vm.startPrank(tester);

        // bound between 3 and 18
        underlyingDecimals %= 16;
        underlyingDecimals += 3;

        // bound the initial yield below 10x the initial underlying
        if (initialUnderlyingAmount != 0) {
            initialYieldAmount = uint192(
                initialYieldAmount % (uint256(initialUnderlyingAmount) * 10)
            );
        } else {
            initialYieldAmount = 0;
        }

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(tester, address(vault), underlyingAmount);

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(tester1, address(vault), underlyingAmount);

        // switch to tester
        vm.stopPrank();
        vm.startPrank(tester);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(address(vault))
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                address(vault)
            );
            underlying.mint(address(vault), additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(address(vault)) -
                    beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(address(vault)).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYield(recipient, address(vault));

        // tester should've received the correct amount of yield
        uint256 epsilonInv = 10**(underlyingDecimals - 3);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYield(tester1, address(vault)),
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_transferFromPYT_toUninitializedAccount(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount,
        uint8 pytTransferPercent
    ) public {
        vm.startPrank(tester);

        // bound between 3 and 18
        underlyingDecimals %= 16;
        underlyingDecimals += 3;

        // bound the initial yield below 100x the initial underlying
        if (initialUnderlyingAmount != 0) {
            initialYieldAmount = uint192(
                initialYieldAmount % (uint256(initialUnderlyingAmount) * 100)
            );
        } else {
            initialYieldAmount = 0;
        }

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

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
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(address(vault))
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                address(vault)
            );
            underlying.mint(address(vault), additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(address(vault)) -
                    beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYield(recipient, address(vault));

        // tester should've received all the yield
        uint256 epsilonInv = 10**(underlyingDecimals - 3);
        assertEqDecimalEpsilonBelow(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should have received 0
        epsilonInv = 10**(underlyingDecimals - 2);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertLeDecimal(
            gate.claimYield(tester1, address(vault)),
            testerClaimedYield / epsilonInv,
            underlyingDecimals
        );
    }

    function test_transferFromPYT_toInitializedAccount(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount,
        uint8 pytTransferPercent
    ) public {
        vm.startPrank(tester);

        // bound between 3 and 18
        underlyingDecimals %= 16;
        underlyingDecimals += 3;

        // bound the initial yield below 10x the initial underlying
        if (initialUnderlyingAmount != 0) {
            initialYieldAmount = uint192(
                initialYieldAmount % (uint256(initialUnderlyingAmount) * 10)
            );
        } else {
            initialYieldAmount = 0;
        }

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, TestYearnVault vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(tester, address(vault), underlyingAmount);

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(tester1, address(vault), underlyingAmount);

        // switch to tester
        vm.stopPrank();
        vm.startPrank(tester);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(address(vault))
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                address(vault)
            );
            underlying.mint(address(vault), additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(address(vault)) -
                    beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(
            address(vault)
        );
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYield(recipient, address(vault));

        // tester should've received the correct amount of yield
        uint256 epsilonInv = 10**(underlyingDecimals - 3);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYield(tester1, address(vault)),
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

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

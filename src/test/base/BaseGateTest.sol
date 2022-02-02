// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseTest, console} from "../base/BaseTest.sol";

import {Gate} from "../../Gate.sol";
import {FullMath} from "../../lib/FullMath.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {NegativeYieldToken} from "../../NegativeYieldToken.sol";
import {PerpetualYieldToken} from "../../PerpetualYieldToken.sol";

abstract contract BaseGateTest is BaseTest {
    /// -----------------------------------------------------------------------
    /// Global state
    /// -----------------------------------------------------------------------

    Gate internal gate;
    address internal constant tester = address(0x69);
    address internal constant tester1 = address(0xabcd);
    address internal constant recipient = address(0xbeef);
    address internal constant initialDepositor = address(0x420);

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    function setUp() public {
        gate = _deployGate();
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        uint256 beforeVaultUnderlyingBalance = underlying.balanceOf(vault);
        uint256 mintAmount = gate.enterWithUnderlying(
            recipient,
            vault,
            underlyingAmount
        );

        // check balances
        // underlying transferred from tester to vault
        assertEqDecimal(underlying.balanceOf(tester), 0, underlyingDecimals);
        assertEqDecimal(
            underlying.balanceOf(vault) - beforeVaultUnderlyingBalance,
            underlyingAmount,
            underlyingDecimals
        );
        // recipient received NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        assertEqDecimal(
            nyt.balanceOf(recipient),
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
        if (!gate.vaultSharesIsERC20()) return;

        vm.startPrank(tester);

        // bound between 0 and 18
        underlyingDecimals %= 19;

        if (initialUnderlyingAmount == 0 && initialYieldAmount != 0) {
            // don't give tester free yield
            initialUnderlyingAmount = initialYieldAmount;
        }

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying and enter vault
        underlying.mint(tester, underlyingAmount);
        uint256 vaultSharesAmount = _depositInVault(vault, underlyingAmount);
        // due to the precision limitations of the vault, we might've lost some underlying
        underlyingAmount = uint192(
            FullMath.mulDiv(
                vaultSharesAmount,
                gate.getPricePerVaultShare(vault),
                10**underlyingDecimals
            )
        );

        // enter
        ERC20(vault).approve(address(gate), type(uint256).max);
        uint256 mintAmount = gate.enterWithVaultShares(
            recipient,
            vault,
            vaultSharesAmount
        );

        // check balances
        // vault shares transferred from tester to gate
        assertEqDecimal(ERC20(vault).balanceOf(tester), 0, underlyingDecimals);
        assertEqDecimal(
            ERC20(vault).balanceOf(address(gate)),
            vaultSharesAmount,
            underlyingDecimals
        );
        // recipient received NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        uint256 epsilonInv = 10**53;
        assertEqDecimalEpsilonBelow(
            nyt.balanceOf(recipient),
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        underlying.mint(vault, additionalYieldAmount);

        // exit
        uint256 burnAmount = gate.exitToUnderlying(
            recipient,
            vault,
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
        // recipient burnt NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        assertEqDecimalEpsilonBelow(
            nyt.balanceOf(recipient),
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
        if (!gate.vaultSharesIsERC20()) return;

        vm.startPrank(tester);

        // bound between 0 and 18
        underlyingDecimals %= 19;

        if (initialUnderlyingAmount == 0 && initialYieldAmount != 0) {
            // don't give tester free yield
            initialUnderlyingAmount = initialYieldAmount;
        }

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        underlying.mint(vault, additionalYieldAmount);

        // exit
        uint256 vaultSharesAmount = FullMath.mulDiv(
            underlyingAmount,
            10**underlyingDecimals,
            gate.getPricePerVaultShare(vault)
        );
        uint256 burnAmount = gate.exitToVaultShares(
            recipient,
            vault,
            vaultSharesAmount
        );

        // check balances
        uint256 epsilonInv = 10**52;
        // vault shares transferred to tester
        assertEqDecimalEpsilonBelow(
            ERC20(vault).balanceOf(recipient),
            vaultSharesAmount,
            underlyingDecimals,
            epsilonInv
        );
        // recipient burnt NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        assertEqDecimalEpsilonBelow(
            nyt.balanceOf(recipient),
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
        address vault = _deployVault(underlying);
        (NegativeYieldToken nyt, PerpetualYieldToken pyt) = gate
            .deployTokenPairForVault(vault);

        assertEq(
            address(gate.getNegativeYieldTokenForVault(vault)),
            address(nyt)
        );
        assertEq(
            address(gate.getPerpetualYieldTokenForVault(vault)),
            address(pyt)
        );
        assertEq(nyt.name(), _getExpectedNYTName());
        assertEq(pyt.name(), _getExpectedPYTName());
        assertEq(nyt.symbol(), _getExpectedNYTSymbol());
        assertEq(pyt.symbol(), _getExpectedPYTSymbol());
        assertEq(nyt.decimals(), underlyingDecimals);
        assertEq(pyt.decimals(), underlyingDecimals);
        assertEq(nyt.totalSupply(), 0);
        assertEq(pyt.totalSupply(), 0);
    }

    function test_claimYieldInUnderlying(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount
    ) public {
        vm.startPrank(tester);

        // bound between 0 and 18
        underlyingDecimals %= 19;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }
        uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(vault);
        underlying.mint(vault, additionalYieldAmount);
        uint256 afterPricePerVaultShare = gate.getPricePerVaultShare(vault);

        // claim yield
        uint256 claimedYield = gate.claimYieldInUnderlying(recipient, vault);

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

    function test_claimYieldInVaultShares(
        uint8 underlyingDecimals,
        uint192 initialUnderlyingAmount,
        uint192 initialYieldAmount,
        uint192 additionalYieldAmount,
        uint192 underlyingAmount
    ) public {
        if (!gate.vaultSharesIsERC20()) return;

        vm.startPrank(tester);

        // bound between 0 and 18
        underlyingDecimals %= 19;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }
        uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(vault);
        underlying.mint(vault, additionalYieldAmount);
        uint256 afterPricePerVaultShare = gate.getPricePerVaultShare(vault);

        // claim yield
        uint256 claimedYield = gate.claimYieldInVaultShares(recipient, vault);

        // check received yield
        uint256 expectedYield = FullMath.mulDiv(
            underlyingAmount,
            afterPricePerVaultShare - beforePricePerVaultShare,
            beforePricePerVaultShare
        );
        expectedYield = FullMath.mulDiv(
            expectedYield,
            10**underlyingDecimals,
            afterPricePerVaultShare
        );
        uint256 epsilonInv = 10**10;
        assertEqDecimalEpsilonBelow(
            claimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonBelow(
            ERC20(vault).balanceOf(recipient),
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            underlying.mint(vault, additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(vault) - beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(vault).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received all the yield
        uint256 epsilonInv = 10**underlyingDecimals;
        assertEqDecimalEpsilonBelow(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should have received 0
        epsilonInv = 10**(underlyingDecimals - 1);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertLeDecimal(
            gate.claimYieldInUnderlying(tester1, vault),
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(tester1, vault, underlyingAmount);

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
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            underlying.mint(vault, additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(vault) - beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(vault).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received the correct amount of yield
        uint256 epsilonInv = 10**underlyingDecimals;
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        epsilonInv = 10**(underlyingDecimals - 2);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYieldInUnderlying(tester1, vault),
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // mint additional yield to the vault
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        {
            uint192 minYieldAmount = uint192(
                (uint256(underlyingAmount) +
                    uint256(initialUnderlyingAmount) +
                    uint256(initialYieldAmount)) /
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            underlying.mint(vault, additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(vault) - beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received all the yield
        uint256 epsilonInv = 10**underlyingDecimals;
        assertEqDecimalEpsilonBelow(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should have received 0
        epsilonInv = 10**(underlyingDecimals - 1);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertLeDecimal(
            gate.claimYieldInUnderlying(tester1, vault),
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

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(tester, vault, underlyingAmount);

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(tester1, vault, underlyingAmount);

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
                    gate.getPricePerVaultShare(vault)
            );
            if (additionalYieldAmount < minYieldAmount) {
                additionalYieldAmount = minYieldAmount;
            }
        }

        uint256 expectedYield;
        {
            uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            underlying.mint(vault, additionalYieldAmount);
            expectedYield = FullMath.mulDiv(
                underlyingAmount,
                gate.getPricePerVaultShare(vault) - beforePricePerVaultShare,
                beforePricePerVaultShare
            );
        }

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received the correct amount of yield
        uint256 epsilonInv = 10**underlyingDecimals;
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        epsilonInv = 10**(underlyingDecimals - 2);
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYieldInUnderlying(tester1, vault),
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

    /// -----------------------------------------------------------------------
    /// Failure tests
    /// -----------------------------------------------------------------------

    function testFail_cannotCallPYTTransferHook(
        address from,
        address to,
        uint256 amount
    ) public {
        gate.beforePerpetualYieldTokenTransfer(from, to, amount);
    }

    function testFail_cannotDeployTokensTwice(uint8 underlyingDecimals) public {
        TestERC20 underlying = new TestERC20(underlyingDecimals);
        address vault = _deployVault(underlying);
        gate.deployTokenPairForVault(vault);
        gate.deployTokenPairForVault(vault);
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    function _setUpVault(
        uint8 underlyingDecimals,
        uint256 initialUnderlyingAmount,
        uint256 initialYieldAmount
    ) internal returns (TestERC20 underlying, address vault) {
        // setup contracts
        underlying = new TestERC20(underlyingDecimals);
        vault = _deployVault(underlying);
        underlying.approve(address(gate), type(uint256).max);
        underlying.approve(vault, type(uint256).max);
        gate.deployTokenPairForVault(vault);

        // initialize deposits & yield
        underlying.mint(initialDepositor, initialUnderlyingAmount);
        vm.prank(initialDepositor);
        underlying.approve(vault, type(uint256).max);
        vm.prank(initialDepositor);
        _depositInVault(vault, initialUnderlyingAmount);
        underlying.mint(vault, initialYieldAmount);
    }

    /// -----------------------------------------------------------------------
    /// Mixins
    /// -----------------------------------------------------------------------

    function _deployGate() internal virtual returns (Gate gate_);

    function _deployVault(ERC20 underlying)
        internal
        virtual
        returns (address vault);

    function _depositInVault(address vault, uint256 underlyingAmount)
        internal
        virtual
        returns (uint256);

    function _getExpectedNYTName() internal virtual returns (string memory);

    function _getExpectedNYTSymbol() internal virtual returns (string memory);

    function _getExpectedPYTName() internal virtual returns (string memory);

    function _getExpectedPYTSymbol() internal virtual returns (string memory);
}

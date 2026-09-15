// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";

import { IncentivesMultiClaimer } from "src/dao/operators/IncentivesMultiClaimer.sol";
import { ISimpleReceiver } from "src/interfaces/ISimpleReceiver.sol";

contract IncentivesMultiClaimerTest is Test {
    address internal constant MULTISIG = 0xFE11a5009f2121622271e7dd0FD470264e076af6;
    address internal constant RECEIVER = 0xC9a9C21F8740684129d271Ad1007E87E24858c59;
    IERC20 internal constant RSUP = IERC20(0x419905009e4656fdC02418C7Df35B1E61Ed5F726);

    address internal claimerAccount = address(0xCA11);
    address internal recipient = address(0xBEEF);

    IncentivesMultiClaimer internal multiClaimer;

    event ClaimerSet(address indexed claimer, bool indexed allowed);

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_URL"));

        multiClaimer = new IncentivesMultiClaimer();

        ISimpleReceiver receiver = ISimpleReceiver(RECEIVER);
        vm.prank(receiver.owner());
        receiver.setApprovedClaimer(address(multiClaimer), true);
    }

    function test_Configuration() public view {
        assertEq(multiClaimer.owner(), MULTISIG);
        assertEq(address(multiClaimer.RECEIVER()), RECEIVER);
    }

    function test_SetClaimer() public {
        vm.expectEmit(true, true, false, true, address(multiClaimer));
        emit ClaimerSet(claimerAccount, true);

        vm.prank(MULTISIG);
        multiClaimer.setClaimer(claimerAccount, true);

        assertTrue(multiClaimer.claimers(claimerAccount));

        vm.prank(MULTISIG);
        multiClaimer.setClaimer(claimerAccount, false);

        assertFalse(multiClaimer.claimers(claimerAccount));
    }

    function test_SetClaimerRejectsNonOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        multiClaimer.setClaimer(claimerAccount, true);
    }

    function test_SetClaimerRejectsZeroAddress() public {
        vm.prank(MULTISIG);
        vm.expectRevert("Invalid claimer");
        multiClaimer.setClaimer(address(0), true);
    }

    function test_OwnerCanTransferOwnershipInOneStep() public {
        address newOwner = address(0xA11CE);

        vm.prank(MULTISIG);
        multiClaimer.transferOwnership(newOwner);

        assertEq(multiClaimer.owner(), newOwner);
    }

    function test_ClaimToCaller() public {
        _approveClaimer();
        skip(14 days);

        uint256 balanceBefore = RSUP.balanceOf(claimerAccount);
        vm.prank(claimerAccount);
        uint256 claimed = multiClaimer.claim();

        assertGt(claimed, 0);
        assertEq(RSUP.balanceOf(claimerAccount) - balanceBefore, claimed);
    }

    function test_ClaimToRecipient() public {
        _approveClaimer();
        skip(14 days);

        uint256 balanceBefore = RSUP.balanceOf(recipient);
        vm.prank(claimerAccount);
        uint256 claimed = multiClaimer.claimTo(recipient);

        assertGt(claimed, 0);
        assertEq(RSUP.balanceOf(recipient) - balanceBefore, claimed);
    }

    function test_ClaimRejectsUnapprovedClaimer() public {
        vm.prank(claimerAccount);
        vm.expectRevert("Not approved claimer");
        multiClaimer.claim();
    }

    function test_ClaimToRejectsInvalidRecipient() public {
        _approveClaimer();

        vm.startPrank(claimerAccount);
        vm.expectRevert("Invalid recipient");
        multiClaimer.claimTo(address(0));

        vm.expectRevert("Invalid recipient");
        multiClaimer.claimTo(address(multiClaimer));
        vm.stopPrank();
    }

    function test_RevokedClaimerCannotClaim() public {
        _approveClaimer();

        vm.prank(MULTISIG);
        multiClaimer.setClaimer(claimerAccount, false);

        vm.prank(claimerAccount);
        vm.expectRevert("Not approved claimer");
        multiClaimer.claim();
    }

    function _approveClaimer() internal {
        vm.prank(MULTISIG);
        multiClaimer.setClaimer(claimerAccount, true);
    }
}

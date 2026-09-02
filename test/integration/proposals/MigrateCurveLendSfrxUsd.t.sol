// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MigrateCurveLendSfrxUsd } from "script/proposals/MigrateCurveLendSfrxUsd.s.sol";
import { Protocol } from "src/Constants.sol";
import { IncentivesMultiClaimer } from "src/dao/operators/IncentivesMultiClaimer.sol";
import { IBorrowLimitController } from "src/interfaces/IBorrowLimitController.sol";
import { IResupplyPair } from "src/interfaces/IResupplyPair.sol";
import { ISimpleReceiver } from "src/interfaces/ISimpleReceiver.sol";
import { IVoter } from "src/interfaces/IVoter.sol";
import { BaseProposalTest } from "test/integration/proposals/BaseProposalTest.sol";

contract MigrateCurveLendSfrxUsdTest is BaseProposalTest {
    uint256 internal constant FORK_BLOCK = 25_889_583;

    MigrateCurveLendSfrxUsd public script;

    function setUp() public override {
        super.setUp();
        vm.createSelectFork(vm.envString("MAINNET_URL"), FORK_BLOCK);
        script = new MigrateCurveLendSfrxUsd();
    }

    function test_ProposalPayload() public view {
        IVoter.Action[] memory actions = script.buildProposalCalldata();

        assertEq(actions.length, 3, "unexpected action count");

        assertEq(actions[0].target, script.V1_PAIR(), "V1 action target");
        assertEq(
            keccak256(actions[0].data),
            keccak256(
                abi.encodeWithSelector(
                    IResupplyPair.setBorrowLimit.selector,
                    script.V1_DEPRECATED_BORROW_LIMIT() // nonzero deprecated limit
                )
            ),
            "V1 action calldata"
        );

        assertEq(actions[1].target, Protocol.BORROW_LIMIT_CONTROLLER, "V2 action target");
        assertEq(
            keccak256(actions[1].data),
            keccak256(
                abi.encodeWithSelector(
                    IBorrowLimitController.setPairBorrowLimitRamp.selector,
                    script.V2_PAIR(), // CurveLend V2 sfrxUSD pair
                    script.V2_TARGET_BORROW_LIMIT(), // 40M target borrow limit
                    script.V2_RAMP_END_TIME() // October 1, 2026 at 00:00 UTC
                )
            ),
            "V2 action calldata"
        );

        assertEq(actions[2].target, Protocol.LIQUIDITY_INCENTIVES_RECEIVER, "claimer action target");
        assertEq(
            keccak256(actions[2].data),
            keccak256(
                abi.encodeWithSelector(
                    ISimpleReceiver.setApprovedClaimer.selector,
                    script.INCENTIVES_MULTI_CLAIMER(), // approved claimer
                    true // approved
                )
            ),
            "claimer action calldata"
        );
    }

    function test_ProposalMigratesBorrowCapacity() public {
        IResupplyPair v1Pair = IResupplyPair(script.V1_PAIR());
        IResupplyPair v2Pair = IResupplyPair(script.V2_PAIR());
        (uint128 v1DebtBefore,) = v1Pair.totalBorrow();
        uint256 v2BorrowLimitBefore = v2Pair.borrowLimit();
        IBorrowLimitController.PairBorrowLimit memory v2RampBefore = borrowLimitController.pairLimits(script.V2_PAIR());

        assertGt(v1Pair.borrowLimit(), script.V1_DEPRECATED_BORROW_LIMIT(), "sanity: V1 market already deprecated");
        assertEq(v2RampBefore.targetBorrowLimit, script.CURRENT_V2_TARGET_BORROW_LIMIT(), "sanity: unexpected V2 target");

        _executeProposal();

        (uint128 v1DebtAfter,) = v1Pair.totalBorrow();
        IBorrowLimitController.PairBorrowLimit memory v2RampAfter = borrowLimitController.pairLimits(script.V2_PAIR());

        assertEq(v1Pair.borrowLimit(), script.V1_DEPRECATED_BORROW_LIMIT(), "V1 borrow limit not reduced");
        assertEq(v1DebtAfter, v1DebtBefore, "existing V1 debt changed");
        assertEq(v2RampAfter.prevBorrowLimit, v2BorrowLimitBefore, "unexpected V2 ramp start limit");
        assertEq(v2RampAfter.targetBorrowLimit, script.V2_TARGET_BORROW_LIMIT(), "unexpected V2 ramp target");
        assertEq(uint256(v2RampAfter.endTime), script.V2_RAMP_END_TIME(), "unexpected V2 ramp end");
    }

    function test_V1MarketKeepsEmissionsActive() public {
        _executeProposal();

        uint256 pairRate = rewardHandler.getPairRate(script.V1_PAIR(), 1 weeks, 1e18);
        assertGt(pairRate, 0, "V1 market emissions stalled");
    }

    function test_V2RampReaches40Million() public {
        _executeProposal();

        IBorrowLimitController.PairBorrowLimit memory v2Ramp = borrowLimitController.pairLimits(script.V2_PAIR());
        skip(uint256(v2Ramp.endTime) - block.timestamp);
        borrowLimitController.updatePairBorrowLimit(script.V2_PAIR());

        assertEq(IResupplyPair(script.V2_PAIR()).borrowLimit(), script.V2_TARGET_BORROW_LIMIT(), "V2 target not reached");
    }

    function test_ProposalApprovesIncentivesMultiClaimer() public {
        ISimpleReceiver receiver = ISimpleReceiver(Protocol.LIQUIDITY_INCENTIVES_RECEIVER);
        IncentivesMultiClaimer multiClaimer = IncentivesMultiClaimer(script.INCENTIVES_MULTI_CLAIMER());

        assertGt(address(multiClaimer).code.length, 0, "claimer not deployed");
        assertEq(multiClaimer.owner(), Protocol.DEPLOYER, "unexpected claimer owner");
        assertEq(address(multiClaimer.RECEIVER()), address(receiver), "unexpected claimer receiver");
        assertFalse(receiver.approvedClaimers(address(multiClaimer)), "claimer already approved");
        assertTrue(receiver.approvedClaimers(Protocol.DEPLOYER), "Safe fallback not approved");
        assertTrue(receiver.approvedClaimers(Protocol.OPERATOR_TREASURY_MANAGER_OLD), "TreasuryManager fallback not approved");

        _executeProposal();

        assertTrue(receiver.approvedClaimers(address(multiClaimer)), "claimer not approved");
        assertTrue(receiver.approvedClaimers(Protocol.DEPLOYER), "Safe fallback removed");
        assertTrue(receiver.approvedClaimers(Protocol.OPERATOR_TREASURY_MANAGER_OLD), "TreasuryManager fallback removed");
    }

    function _executeProposal() internal {
        uint256 proposalId = createProposal(script.buildProposalCalldata());
        simulatePassingVote(proposalId);
        executeProposal(proposalId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "lib/forge-std/src/console.sol";
import { Protocol } from "src/Constants.sol";
import { IBorrowLimitController } from "src/interfaces/IBorrowLimitController.sol";
import { IResupplyPair } from "src/interfaces/IResupplyPair.sol";
import { ISimpleReceiver } from "src/interfaces/ISimpleReceiver.sol";
import { IVoter } from "src/interfaces/IVoter.sol";

contract MigrateCurveLendSfrxUsd is Script {
    IVoter public constant VOTER = IVoter(Protocol.VOTER);
    IBorrowLimitController public constant BORROW_LIMIT_CONTROLLER = IBorrowLimitController(Protocol.BORROW_LIMIT_CONTROLLER);

    address public constant V1_PAIR = Protocol.PAIR_CURVELEND_SFRXUSD_CRVUSD;
    address public constant V2_PAIR = Protocol.PAIR_CURVELEND_V2_SFRXUSD_CRVUSD;
    address public constant INCENTIVES_MULTI_CLAIMER = Protocol.INCENTIVES_MULTI_CLAIMER;

    uint256 public constant V1_DEPRECATED_BORROW_LIMIT = 1;
    uint256 public constant CURRENT_V2_TARGET_BORROW_LIMIT = 20_000_000e18;
    uint256 public constant V2_TARGET_BORROW_LIMIT = CURRENT_V2_TARGET_BORROW_LIMIT * 2; // 2x the target limit
    uint256 public constant V2_RAMP_END_TIME = 1_790_812_800; // 2026-10-01 00:00:00 UTC

    string public constant DESCRIPTION = "Migrate sfrxUSD debt limits from V1 to V2 and approve new liquidity incentives claimer contract";

    function run() public {
        IVoter.Action[] memory actions = buildProposalCalldata();
        printCallData(actions);

        vm.startBroadcast();
        (, address proposer,) = vm.readCallers();
        uint256 proposalId = VOTER.createNewProposal(proposer, actions, DESCRIPTION);
        vm.stopBroadcast();

        console.log("Proposal created by:", proposer);
        console.log("Proposal ID:", proposalId);
    }

    function buildProposalCalldata() public view returns (IVoter.Action[] memory actions) {
        require(IResupplyPair(V1_PAIR).borrowLimit() > V1_DEPRECATED_BORROW_LIMIT, "V1 market already deprecated");

        IBorrowLimitController.PairBorrowLimit memory v2Ramp = BORROW_LIMIT_CONTROLLER.pairLimits(V2_PAIR);
        require(v2Ramp.targetBorrowLimit == CURRENT_V2_TARGET_BORROW_LIMIT, "unexpected V2 target borrow limit");
        require(v2Ramp.endTime > block.timestamp, "V2 borrow limit ramp has ended");
        require(V2_RAMP_END_TIME > v2Ramp.endTime, "V2 ramp end is not extended");
        require(V2_RAMP_END_TIME >= block.timestamp + VOTER.votingPeriod() + VOTER.executionDelay() + 7 days, "insufficient V2 ramp duration");
        require(INCENTIVES_MULTI_CLAIMER.code.length > 0, "incentives claimer not deployed");
        require(!ISimpleReceiver(Protocol.LIQUIDITY_INCENTIVES_RECEIVER).approvedClaimers(INCENTIVES_MULTI_CLAIMER), "incentives claimer already approved");

        actions = new IVoter.Action[](3);

        // Reduce V1 borrowing capacity while keeping its emissions weight active.
        actions[0] = IVoter.Action({
            target: V1_PAIR,
            data: abi.encodeWithSelector(
                IResupplyPair.setBorrowLimit.selector,
                V1_DEPRECATED_BORROW_LIMIT // nonzero borrow limit keeps emissions active
            )
        });

        // Double the V2 target, fully realizing the ramp as October begins.
        actions[1] = IVoter.Action({
            target: Protocol.BORROW_LIMIT_CONTROLLER,
            data: abi.encodeWithSelector(
                IBorrowLimitController.setPairBorrowLimitRamp.selector,
                V2_PAIR, // CurveLend V2 sfrxUSD pair
                V2_TARGET_BORROW_LIMIT, // 40M target borrow limit
                V2_RAMP_END_TIME // October 1, 2026 at 00:00 UTC
            )
        });

        // Approve the multi-claimer to claim liquidity-incentive emissions.
        actions[2] = IVoter.Action({
            target: Protocol.LIQUIDITY_INCENTIVES_RECEIVER,
            data: abi.encodeWithSelector(
                ISimpleReceiver.setApprovedClaimer.selector,
                INCENTIVES_MULTI_CLAIMER, // approved claimer
                true // approved
            )
        });
    }

    function printCallData(IVoter.Action[] memory actions) public view {
        for (uint256 i = 0; i < actions.length; i++) {
            console.log("Action", i + 1);
            console.log(actions[i].target);
            console.logBytes(actions[i].data);
            console.log("--------------------------------");
        }
    }
}

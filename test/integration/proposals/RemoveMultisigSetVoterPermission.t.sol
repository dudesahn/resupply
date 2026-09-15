// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { RemoveMultisigSetVoterPermission } from "script/proposals/RemoveMultisigSetVoterPermission.s.sol";
import { Protocol } from "src/Constants.sol";
import { ICore } from "src/interfaces/ICore.sol";
import { IVoter } from "src/interfaces/IVoter.sol";
import { BaseProposalTest } from "test/integration/proposals/BaseProposalTest.sol";

contract RemoveMultisigSetVoterPermissionTest is BaseProposalTest {
    uint256 public constant PROP_ID = 28;

    RemoveMultisigSetVoterPermission public script;

    function setUp() public override {
        super.setUp();
        if (isProposalProcessed(PROP_ID)) vm.skip(true);
        script = new RemoveMultisigSetVoterPermission();
    }

    function test_ProposalPayload() public view {
        IVoter.Action[] memory actions = script.buildProposalCalldata();

        assertEq(actions.length, 1, "unexpected action count");
        assertEq(actions[0].target, Protocol.CORE, "action target");
        assertEq(
            keccak256(actions[0].data),
            keccak256(
                abi.encodeWithSelector(
                    ICore.setOperatorPermissions.selector,
                    Protocol.DEPLOYER, // caller: multisig
                    Protocol.CORE, // target: Core
                    ICore.setVoter.selector, // permission selector
                    false, // authorized
                    address(0) // auth hook
                )
            ),
            "action calldata"
        );
    }

    function test_ProposalRemovesMultisigSetVoterPermission() public {
        (bool authorizedBefore,) = core.operatorPermissions(Protocol.DEPLOYER, Protocol.CORE, ICore.setVoter.selector);
        assertTrue(authorizedBefore, "sanity: permission not enabled before proposal");

        address voterBefore = core.voter();
        uint256 proposalId = createProposal(script.buildProposalCalldata());
        simulatePassingVote(proposalId);
        executeProposal(proposalId);

        (bool authorizedAfter,) = core.operatorPermissions(Protocol.DEPLOYER, Protocol.CORE, ICore.setVoter.selector);
        assertFalse(authorizedAfter, "permission not removed");
        assertEq(core.voter(), voterBefore, "voter changed");
    }
}

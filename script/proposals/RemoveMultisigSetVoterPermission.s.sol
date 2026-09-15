// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console } from "lib/forge-std/src/console.sol";
import { Protocol } from "src/Constants.sol";
import { ICore } from "src/interfaces/ICore.sol";
import { IVoter } from "src/interfaces/IVoter.sol";

contract RemoveMultisigSetVoterPermission is Script {
    ICore public constant CORE = ICore(Protocol.CORE);
    IVoter public constant VOTER = IVoter(Protocol.VOTER);

    address public constant MULTISIG = Protocol.DEPLOYER;
    string public constant DESCRIPTION = "Remove SetVoter operator permission";

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
        (bool authorized,) = CORE.operatorPermissions(MULTISIG, Protocol.CORE, ICore.setVoter.selector);
        require(authorized, "Multisig setVoter permission is not enabled");

        actions = new IVoter.Action[](1);

        // Revoke the multisig's launch-era authority to replace the protocol Voter.
        actions[0] = IVoter.Action({
            target: Protocol.CORE,
            data: abi.encodeWithSelector(
                ICore.setOperatorPermissions.selector,
                MULTISIG, // caller: multisig
                Protocol.CORE, // target: Core
                ICore.setVoter.selector, // permission selector
                false, // authorized
                address(0) // auth hook
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

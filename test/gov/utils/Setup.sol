// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import { IERC20, SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IGovStaker} from "../../../src/interfaces/IGovStaker.sol";
import {ICore} from "../../../src/interfaces/ICore.sol";
import {GovStaker} from "../../../src/dao/staking/GovStaker.sol";
import {Core} from "../../../src/dao/Core.sol";
import {MockToken} from "../../mocks/MockToken.sol";
import {GovStakerEscrow} from "../../../src/dao/staking/GovStakerEscrow.sol";
import {IGovStakerEscrow} from "../../../src/interfaces/IGovStakerEscrow.sol";

contract Setup is Test {
    ICore public core;
    IGovStaker public staker;
    GovStakerEscrow public escrow;
    MockToken public stakingToken;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    address dev = address(0x42069);
    address tempGov = address(987);
    address guardian = address(654);
    address feeReceiver = address(321);

    function setUp() public virtual {
        // Deploy the mock factory first for deterministic location
        stakingToken = new MockToken("GovToken", "GOV");

        staker = IGovStaker(deployStaker());

        // label all the used addresses for traces
        vm.label(address(stakingToken), "Gov Token");
        vm.label(address(tempGov), "Temp Gov");
        vm.label(address(feeReceiver), "Fee Receiver");
        vm.label(address(guardian), "Guardian");
        vm.label(address(core), "Core");
    }

    function deployStaker() public returns (address) {
        core = ICore(address(new Core(tempGov, 1 weeks, guardian, feeReceiver)));
        uint256 nonce = vm.getNonce(address(this));
        address escrowAddress = computeCreateAddress(address(this), nonce);
        address govStakingAddress = computeCreateAddress(address(this), nonce + 1);
        escrow = new GovStakerEscrow(govStakingAddress, address(stakingToken));

        return address(
            new GovStaker(
                address(core), 
                address(stakingToken), 
                IGovStakerEscrow(escrowAddress), 
                2
            )
        );
    }

}
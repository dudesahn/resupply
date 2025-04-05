pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Setup} from "../../Setup.sol";
import {SimpleReceiverFactory} from "../../../src/dao/emissions/receivers/SimpleReceiverFactory.sol";
import {SimpleReceiver} from "../../../src/dao/emissions/receivers/SimpleReceiver.sol";
import {GovToken} from "../../../src/dao/GovToken.sol";
import {EmissionsController} from "../../../src/dao/emissions/EmissionsController.sol";

contract SimpleReceiverFactoryTest is Setup {
    address public simpleReceiverImplementation;
    SimpleReceiverFactory public simpleReceiverFactory;

    function setUp() public override {
        super.setUp();
        emissionsController = new EmissionsController(
            address(core), // core
            address(govToken), // govtoken
            getEmissionsSchedule(), // emissions
            1, // epochs per
            0, // tail rate
            0 // bootstrap epochs
        );
        vm.prank(address(core));
        govToken.setMinter(address(emissionsController));
        simpleReceiverImplementation = address(
            new SimpleReceiver(address(core), address(emissionsController))
        );

        simpleReceiverFactory = new SimpleReceiverFactory(
            address(core),
            address(emissionsController),
            simpleReceiverImplementation
        );
    }

    function test_ReceiverLookupByAddress() public {
        address predictedReceiverAddress = simpleReceiverFactory
            .getDeterministicAddress("Test Receiver");
        vm.prank(address(core));
        address receiver = simpleReceiverFactory.deployNewReceiver(
            "Test Receiver",
            new address[](0)
        );
        assertEq(receiver, predictedReceiverAddress);
        address receiverByName = simpleReceiverFactory.getReceiverByName(
            "Test Receiver"
        );
        assertEq(receiverByName, receiver);
    }

    function test_AllocateEmissions() public {
        vm.startPrank(address(core));
        SimpleReceiver receiver = SimpleReceiver(
            simpleReceiverFactory.deployNewReceiver(
                "Test Receiver",
                new address[](0)
            )
        );
        emissionsController.registerReceiver(address(receiver));
        assertTrue(emissionsController.isRegisteredReceiver(address(receiver)));

        uint256 amount = receiver.allocateEmissions();
        assertEq(amount, 0);
        skip(epochLength);
        amount = receiver.allocateEmissions();
        assertGt(amount, 0);
        assertEq(receiver.claimableEmissions(), amount);

        assertEq(receiver.claimEmissions(address(user1)), amount);
        (, uint256 allocated) = emissionsController.allocated(
            address(receiver)
        );
        assertEq(allocated, 0);
        assertEq(receiver.claimableEmissions(), 0);
        vm.stopPrank();
    }

    function test_ReceiverAccessControl() public {
        address[] memory approvedClaimers = new address[](1);
        approvedClaimers[0] = user1;
        vm.prank(address(core));
        SimpleReceiver receiver = SimpleReceiver(
            simpleReceiverFactory.deployNewReceiver(
                "Test Receiver",
                approvedClaimers
            )
        );

        vm.prank(address(core));
        emissionsController.registerReceiver(address(receiver));
        assertTrue(emissionsController.isRegisteredReceiver(address(receiver)));

        skip(epochLength * (emissionsController.BOOTSTRAP_EPOCHS() + 1));

        vm.prank(address(user2));
        vm.expectRevert("Not approved claimer");
        receiver.claimEmissions(address(user2));

        vm.prank(address(user1));
        uint256 amount = receiver.claimEmissions(address(user1));
        assertGt(amount, 0);

        skip(epochLength);

        vm.prank(address(core));
        amount = receiver.claimEmissions(address(user1));
        assertGt(amount, 0);
    }

    function test_SetApprovedClaimer() public {
        vm.prank(address(core));
        SimpleReceiver receiver = SimpleReceiver(
            simpleReceiverFactory.deployNewReceiver(
                "Test Receiver",
                new address[](0)
            )
        );

        assertEq(receiver.approvedClaimers(user1), false);

        vm.prank(address(core));
        receiver.setApprovedClaimer(user1, true);
        assertEq(receiver.approvedClaimers(user1), true);
    }
}

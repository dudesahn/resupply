// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ISimpleReceiver } from "../../interfaces/ISimpleReceiver.sol";

contract IncentivesMultiClaimer is Ownable {
    ISimpleReceiver public constant RECEIVER = ISimpleReceiver(0xC9a9C21F8740684129d271Ad1007E87E24858c59);

    mapping(address claimer => bool allowed) public claimers;

    event ClaimerSet(address indexed claimer, bool indexed allowed);

    constructor() Ownable(0xFE11a5009f2121622271e7dd0FD470264e076af6) { }

    modifier onlyClaimer() {
        require(claimers[msg.sender], "Not approved claimer");
        _;
    }

    function setClaimer(address claimer, bool allowed) external onlyOwner {
        require(claimer != address(0), "Invalid claimer");

        claimers[claimer] = allowed;
        emit ClaimerSet(claimer, allowed);
    }

    function claim() external returns (uint256 amount) {
        return claimTo(msg.sender);
    }

    function claimTo(address recipient) public onlyClaimer returns (uint256 amount) {
        require(recipient != address(0) && recipient != address(this), "Invalid recipient");

        return RECEIVER.claimEmissions(recipient);
    }
}

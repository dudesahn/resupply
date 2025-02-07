// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOwnership {
    function owner() external view returns(address);
    function pendingOwner() external view returns(address);
    function acceptPendingOwner() external;
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IRemoteStrategyAgent} from "../interfaces/crosschain/IRemoteStrategyAgent.sol";

contract RemoteStrategyAgent is CrossChainAccessControl, IRemoteStrategyAgent {
    error RemoteStrategyAgent__NotImplemented();

    uint32 public immutable strategyId;

    constructor(
        address admin,
        uint32 strategyId_
    ) CrossChainAccessControl(admin) {
        strategyId = strategyId_;
    }

    function receiveBridgeAsset(
        bytes calldata payload
    ) external onlyRole(BRIDGE_ROLE) {
        emit CommandReceived(keccak256(payload), strategyId);
        revert RemoteStrategyAgent__NotImplemented();
    }

    function executeAllocate(
        bytes calldata command
    ) external onlyRole(KEEPER_ROLE) {
        emit CommandExecuted(keccak256(command), strategyId);
        revert RemoteStrategyAgent__NotImplemented();
    }

    function executeRecall(
        bytes calldata command
    ) external onlyRole(KEEPER_ROLE) {
        emit CommandExecuted(keccak256(command), strategyId);
        revert RemoteStrategyAgent__NotImplemented();
    }

    function harvest(bytes calldata command) external onlyRole(KEEPER_ROLE) {
        emit CommandExecuted(keccak256(command), strategyId);
        revert RemoteStrategyAgent__NotImplemented();
    }

    function emergencyExit(
        bytes calldata command
    ) external onlyRole(GUARDIAN_ROLE) {
        emit CommandExecuted(keccak256(command), strategyId);
        revert RemoteStrategyAgent__NotImplemented();
    }
}

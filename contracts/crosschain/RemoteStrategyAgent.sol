// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IBridgeAdapter} from "../interfaces/crosschain/IBridgeAdapter.sol";
import {IRemoteStrategyAgent} from "../interfaces/crosschain/IRemoteStrategyAgent.sol";
import {IStrategyAdapter} from "../interfaces/crosschain/IStrategyAdapter.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract RemoteStrategyAgent is CrossChainAccessControl, IRemoteStrategyAgent {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error RemoteStrategyAgent__AssetNotConfigured();
    error RemoteStrategyAgent__StrategyAdapterNotConfigured();
    error RemoteStrategyAgent__InvalidAsset();
    error RemoteStrategyAgent__InvalidStrategyAdapter();
    error RemoteStrategyAgent__InvalidStrategyId(uint32 strategyId);
    error RemoteStrategyAgent__UnsupportedCommandType(
        CrossChainTypes.CommandType commandType
    );
    error RemoteStrategyAgent__UnknownCommand(bytes32 opId);
    error RemoteStrategyAgent__CommandAlreadyReceived(bytes32 opId);
    error RemoteStrategyAgent__CommandAlreadyExecuted(bytes32 opId);
    error RemoteStrategyAgent__CommandNotExecuted(bytes32 opId);
    error RemoteStrategyAgent__CommandAlreadyBridged(bytes32 opId);
    error RemoteStrategyAgent__PayloadMismatch(bytes32 opId);
    error RemoteStrategyAgent__DeadlineExpired(
        bytes32 opId,
        uint64 deadline,
        uint64 timestamp
    );
    error RemoteStrategyAgent__InsufficientIdleAssets(
        uint256 requiredAssets,
        uint256 idleAssets
    );
    error RemoteStrategyAgent__InsufficientFreedAssets(
        uint256 minAssetsOut,
        uint256 assetsFreed
    );
    error RemoteStrategyAgent__AssetBalanceInvariant(
        uint256 balance,
        uint256 trackedIdleAssets
    );
    error RemoteStrategyAgent__InvalidBridgeAdapter();
    error RemoteStrategyAgent__InvalidReportChainId();
    error RemoteStrategyAgent__InvalidReportLiquidity(
        uint256 totalValue,
        uint256 freeLiquidity
    );

    struct StoredCommand {
        bytes32 payloadHash;
        bytes32 bridgeMessageId;
        CrossChainTypes.CommandType commandType;
        uint256 assets;
        uint256 minAssetsOut;
        uint256 executedAssets;
        uint64 deadline;
        uint64 receivedAt;
        uint64 executedAt;
        uint64 bridgedAt;
    }

    uint32 private immutable STRATEGY_ID;
    address public asset;
    IStrategyAdapter private _strategyAdapter;
    uint256 public idleAssets;
    uint256 public deployedAssets;
    uint64 public lastPreparedReportTimestamp;

    mapping(bytes32 opId => StoredCommand command) private _commands;

    constructor(
        address admin,
        uint32 strategyId_
    ) CrossChainAccessControl(admin) {
        STRATEGY_ID = strategyId_;
    }

    function strategyId() public view returns (uint32) {
        return STRATEGY_ID;
    }

    function getCommandState(
        bytes32 opId
    ) external view returns (StoredCommand memory) {
        return _commands[opId];
    }

    function strategyAdapter() public view returns (address) {
        return address(_strategyAdapter);
    }

    function setAsset(
        address asset_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (asset_ == address(0)) {
            revert RemoteStrategyAgent__InvalidAsset();
        }

        asset = asset_;
        emit AssetConfigured(asset_);
    }

    function setStrategyAdapter(
        address strategyAdapter_
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (strategyAdapter_ == address(0)) {
            revert RemoteStrategyAgent__InvalidStrategyAdapter();
        }

        _strategyAdapter = IStrategyAdapter(strategyAdapter_);
        emit StrategyAdapterConfigured(strategyAdapter_);
    }

    function receiveBridgeAsset(
        bytes calldata payload
    ) external onlyRole(BRIDGE_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory command = _decodeAndValidateCommand(
            payload
        );
        StoredCommand storage storedCommand = _commands[command.opId];
        if (storedCommand.receivedAt != 0) {
            revert RemoteStrategyAgent__CommandAlreadyReceived(command.opId);
        }

        storedCommand.payloadHash = keccak256(payload);
        storedCommand.commandType = command.commandType;
        storedCommand.assets = command.assets;
        storedCommand.minAssetsOut = command.minAssetsOut;
        storedCommand.executedAssets = 0;
        storedCommand.deadline = command.deadline;
        storedCommand.receivedAt = uint64(block.timestamp);

        if (command.commandType == CrossChainTypes.CommandType.Allocate) {
            idleAssets += command.assets;
            _assertIdleAssetBalance();
        }

        emit CommandReceived(command.opId, STRATEGY_ID);
    }

    function executeAllocate(
        bytes calldata command
    ) external onlyRole(KEEPER_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requirePendingCommand(
            command,
            CrossChainTypes.CommandType.Allocate
        );
        if (idleAssets < payload.assets) {
            revert RemoteStrategyAgent__InsufficientIdleAssets(
                payload.assets,
                idleAssets
            );
        }

        IERC20(asset).forceApprove(address(_strategyAdapter), payload.assets);
        _strategyAdapter.deployCapital(payload.assets, payload.params);
        IERC20(asset).forceApprove(address(_strategyAdapter), 0);

        idleAssets -= payload.assets;
        deployedAssets += payload.assets;
        _markCommandExecuted(payload.opId, payload.assets);

        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function executeRecall(
        bytes calldata command
    ) external onlyRole(KEEPER_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requirePendingCommand(
            command,
            CrossChainTypes.CommandType.Recall
        );
        uint256 assetsFreed = _strategyAdapter.freeCapital(
            payload.assets,
            payload.params
        );
        if (assetsFreed < payload.minAssetsOut) {
            revert RemoteStrategyAgent__InsufficientFreedAssets(
                payload.minAssetsOut,
                assetsFreed
            );
        }

        idleAssets += assetsFreed;
        if (assetsFreed >= deployedAssets) {
            deployedAssets = 0;
        } else {
            deployedAssets -= assetsFreed;
        }
        _assertIdleAssetBalance();
        _markCommandExecuted(payload.opId, assetsFreed);

        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function bridgeAssetsHome(
        bytes calldata command,
        address bridgeAdapter,
        uint32 dstEid
    ) external onlyRole(BRIDGE_ROLE) returns (bytes32 messageId) {
        _requireConfigured();
        if (bridgeAdapter == address(0)) {
            revert RemoteStrategyAgent__InvalidBridgeAdapter();
        }

        CrossChainTypes.CommandPayloadV1 memory payload = _requireBridgeableCommand(
            command
        );
        StoredCommand storage storedCommand = _commands[payload.opId];

        if (idleAssets < storedCommand.executedAssets) {
            revert RemoteStrategyAgent__InsufficientIdleAssets(
                storedCommand.executedAssets,
                idleAssets
            );
        }

        IERC20(asset).forceApprove(bridgeAdapter, storedCommand.executedAssets);
        messageId = IBridgeAdapter(bridgeAdapter).sendAssetAndMessage(
            dstEid,
            asset,
            storedCommand.executedAssets,
            command
        );
        IERC20(asset).forceApprove(bridgeAdapter, 0);

        idleAssets -= storedCommand.executedAssets;
        storedCommand.bridgeMessageId = messageId;
        storedCommand.bridgedAt = uint64(block.timestamp);

        emit CommandBridged(
            payload.opId,
            messageId,
            dstEid,
            storedCommand.executedAssets
        );
    }

    function harvest(bytes calldata command) external onlyRole(KEEPER_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requirePendingCommand(
            command,
            CrossChainTypes.CommandType.Harvest
        );
        (, uint256 assetsOut) = _strategyAdapter.harvest(payload.params);

        idleAssets += assetsOut;
        _assertIdleAssetBalance();
        _markCommandExecuted(payload.opId, assetsOut);

        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function emergencyExit(
        bytes calldata command
    ) external onlyRole(GUARDIAN_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requirePendingCommand(
            command,
            CrossChainTypes.CommandType.EmergencyExit
        );
        uint256 assetsOut = _strategyAdapter.emergencyExit(payload.params);

        idleAssets += assetsOut;
        deployedAssets = 0;
        _assertIdleAssetBalance();
        _markCommandExecuted(payload.opId, assetsOut);

        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function previewStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external view returns (CrossChainTypes.StrategyReport memory report) {
        _requireConfigured();
        report = _buildStrategyReport(
            chainId,
            positionsHash,
            uint64(block.timestamp)
        );
    }

    function prepareStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    )
        external
        onlyRole(REPORTER_ROLE)
        returns (CrossChainTypes.StrategyReport memory report)
    {
        _requireConfigured();
        report = _buildStrategyReport(
            chainId,
            positionsHash,
            uint64(block.timestamp)
        );
        lastPreparedReportTimestamp = report.reportTimestamp;

        emit StrategyReportPrepared(
            report.strategyId,
            report.chainId,
            report.reportTimestamp,
            report.positionsHash,
            report.totalValue,
            report.freeLiquidity,
            report.totalDebt,
            report.pnl
        );
    }

    function _requireConfigured() internal view {
        if (asset == address(0)) {
            revert RemoteStrategyAgent__AssetNotConfigured();
        }
        if (address(_strategyAdapter) == address(0)) {
            revert RemoteStrategyAgent__StrategyAdapterNotConfigured();
        }
    }

    function _decodeAndValidateCommand(
        bytes calldata payload
    ) internal view returns (CrossChainTypes.CommandPayloadV1 memory command) {
        command = abi.decode(payload, (CrossChainTypes.CommandPayloadV1));
        if (command.strategyId != STRATEGY_ID) {
            revert RemoteStrategyAgent__InvalidStrategyId(command.strategyId);
        }
        if (
            command.commandType != CrossChainTypes.CommandType.Allocate &&
            command.commandType != CrossChainTypes.CommandType.Recall &&
            command.commandType != CrossChainTypes.CommandType.Harvest &&
            command.commandType != CrossChainTypes.CommandType.EmergencyExit
        ) {
            revert RemoteStrategyAgent__UnsupportedCommandType(
                command.commandType
            );
        }
        _requireActiveDeadline(command.opId, command.deadline);
    }

    function _requirePendingCommand(
        bytes calldata command,
        CrossChainTypes.CommandType expectedCommandType
    ) internal view returns (CrossChainTypes.CommandPayloadV1 memory payload) {
        payload = _decodeAndValidateCommand(command);

        StoredCommand memory storedCommand = _commands[payload.opId];
        if (storedCommand.receivedAt == 0) {
            revert RemoteStrategyAgent__UnknownCommand(payload.opId);
        }
        if (storedCommand.executedAt != 0) {
            revert RemoteStrategyAgent__CommandAlreadyExecuted(payload.opId);
        }
        if (storedCommand.commandType != expectedCommandType) {
            revert RemoteStrategyAgent__UnsupportedCommandType(
                payload.commandType
            );
        }
        if (storedCommand.payloadHash != keccak256(command)) {
            revert RemoteStrategyAgent__PayloadMismatch(payload.opId);
        }
    }

    function _markCommandExecuted(bytes32 opId, uint256 executedAssets) internal {
        _commands[opId].executedAt = uint64(block.timestamp);
        _commands[opId].executedAssets = executedAssets;
    }

    function _requireActiveDeadline(bytes32 opId, uint64 deadline) internal view {
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline < block.timestamp) {
            revert RemoteStrategyAgent__DeadlineExpired(
                opId,
                deadline,
                uint64(block.timestamp)
            );
        }
    }

    function _assertIdleAssetBalance() internal view {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance < idleAssets) {
            revert RemoteStrategyAgent__AssetBalanceInvariant(
                balance,
                idleAssets
            );
        }
    }

    function _requireBridgeableCommand(
        bytes calldata command
    ) internal view returns (CrossChainTypes.CommandPayloadV1 memory payload) {
        payload = _decodeAndValidateCommand(command);

        StoredCommand memory storedCommand = _commands[payload.opId];
        if (storedCommand.receivedAt == 0) {
            revert RemoteStrategyAgent__UnknownCommand(payload.opId);
        }
        if (storedCommand.executedAt == 0) {
            revert RemoteStrategyAgent__CommandNotExecuted(payload.opId);
        }
        if (storedCommand.bridgedAt != 0) {
            revert RemoteStrategyAgent__CommandAlreadyBridged(payload.opId);
        }
        if (storedCommand.payloadHash != keccak256(command)) {
            revert RemoteStrategyAgent__PayloadMismatch(payload.opId);
        }
        if (
            storedCommand.commandType == CrossChainTypes.CommandType.Allocate ||
            storedCommand.commandType == CrossChainTypes.CommandType.Ack ||
            storedCommand.commandType == CrossChainTypes.CommandType.Report
        ) {
            revert RemoteStrategyAgent__UnsupportedCommandType(
                storedCommand.commandType
            );
        }
    }

    function _buildStrategyReport(
        uint32 chainId,
        bytes32 positionsHash,
        uint64 reportTimestamp
    ) internal view returns (CrossChainTypes.StrategyReport memory report) {
        if (chainId == 0) {
            revert RemoteStrategyAgent__InvalidReportChainId();
        }

        uint256 strategyValue = _strategyAdapter.totalValue();
        uint256 strategyFreeLiquidity = _strategyAdapter.freeLiquidity();
        if (strategyFreeLiquidity > strategyValue) {
            revert RemoteStrategyAgent__InvalidReportLiquidity(
                strategyValue,
                strategyFreeLiquidity
            );
        }

        int256 pnl;
        if (strategyValue >= deployedAssets) {
            pnl = (strategyValue - deployedAssets).toInt256();
        } else {
            pnl = -((deployedAssets - strategyValue).toInt256());
        }

        report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: chainId,
            totalValue: strategyValue,
            freeLiquidity: strategyFreeLiquidity,
            totalDebt: deployedAssets,
            pnl: pnl,
            reportTimestamp: reportTimestamp,
            positionsHash: positionsHash
        });
    }
}

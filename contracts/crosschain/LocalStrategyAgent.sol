// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {ILocalStrategyAgent} from "../interfaces/crosschain/ILocalStrategyAgent.sol";
import {IStrategyAdapter} from "../interfaces/crosschain/IStrategyAdapter.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract LocalStrategyAgent is CrossChainAccessControl, ILocalStrategyAgent {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error LocalStrategyAgent__AssetNotConfigured();
    error LocalStrategyAgent__StrategyAdapterNotConfigured();
    error LocalStrategyAgent__InvalidAsset();
    error LocalStrategyAgent__InvalidStrategyAdapter();
    error LocalStrategyAgent__InvalidVault();
    error LocalStrategyAgent__InvalidStrategyId(uint32 strategyId);
    error LocalStrategyAgent__UnsupportedCommandType(
        CrossChainTypes.CommandType commandType
    );
    error LocalStrategyAgent__CommandAlreadyExecuted(bytes32 opId);
    error LocalStrategyAgent__PayloadMismatch(bytes32 opId);
    error LocalStrategyAgent__DeadlineExpired(
        bytes32 opId,
        uint64 deadline,
        uint64 timestamp
    );
    error LocalStrategyAgent__InsufficientIdleAssets(
        uint256 requiredAssets,
        uint256 idleAssets
    );
    error LocalStrategyAgent__InsufficientFreedAssets(
        uint256 minAssetsOut,
        uint256 assetsFreed
    );
    error LocalStrategyAgent__AssetBalanceInvariant(
        uint256 balance,
        uint256 trackedIdleAssets
    );
    error LocalStrategyAgent__InvalidReportChainId();
    error LocalStrategyAgent__InvalidReportLiquidity(
        uint256 totalValue,
        uint256 freeLiquidity
    );

    struct StoredCommand {
        bytes32 payloadHash;
        CrossChainTypes.CommandType commandType;
        uint256 assets;
        uint256 minAssetsOut;
        uint256 executedAssets;
        uint64 deadline;
        uint64 executedAt;
    }

    event AssetConfigured(address indexed asset);
    event StrategyAdapterConfigured(address indexed adapter);
    event CommandExecuted(bytes32 indexed opId, uint32 indexed strategyId);
    event StrategyReportPrepared(
        uint32 indexed strategyId,
        uint32 indexed chainId,
        uint64 reportTimestamp,
        bytes32 positionsHash,
        uint256 totalValue,
        uint256 freeLiquidity,
        uint256 totalDebt,
        int256 pnl
    );

    uint32 private immutable STRATEGY_ID;
    address public immutable VAULT;
    address public asset;
    IStrategyAdapter private _strategyAdapter;
    uint256 public idleAssets;
    uint256 public deployedAssets;
    uint64 public lastPreparedReportTimestamp;

    mapping(bytes32 opId => StoredCommand command) private _commands;

    constructor(
        address admin,
        uint32 strategyId_,
        address vault_
    ) CrossChainAccessControl(admin) {
        if (vault_ == address(0)) {
            revert LocalStrategyAgent__InvalidVault();
        }
        STRATEGY_ID = strategyId_;
        VAULT = vault_;
    }

    function strategyId() public view returns (uint32) {
        return STRATEGY_ID;
    }

    function strategyAdapter() public view returns (address) {
        return address(_strategyAdapter);
    }

    function setAsset(
        address asset_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        if (asset_ == address(0)) {
            revert LocalStrategyAgent__InvalidAsset();
        }

        asset = asset_;
        emit AssetConfigured(asset_);
    }

    function setStrategyAdapter(
        address strategyAdapter_
    ) external override onlyRole(GOVERNANCE_ROLE) {
        if (strategyAdapter_ == address(0)) {
            revert LocalStrategyAgent__InvalidStrategyAdapter();
        }

        _strategyAdapter = IStrategyAdapter(strategyAdapter_);
        emit StrategyAdapterConfigured(strategyAdapter_);
    }

    function executeAllocate(
        bytes calldata command
    ) external override onlyRole(KEEPER_ROLE) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requireCommand(
            command,
            CrossChainTypes.CommandType.Allocate
        );

        idleAssets += payload.assets;
        _assertIdleAssetBalance();

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
    ) external override onlyRole(KEEPER_ROLE) returns (uint256 assetsFreed) {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requireCommand(
            command,
            CrossChainTypes.CommandType.Recall
        );

        assetsFreed = _strategyAdapter.freeCapital(payload.assets, payload.params);
        if (assetsFreed < payload.minAssetsOut) {
            revert LocalStrategyAgent__InsufficientFreedAssets(
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

        if (assetsFreed != 0) {
            IERC20(asset).safeTransfer(VAULT, assetsFreed);
            idleAssets -= assetsFreed;
        }

        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function harvest(
        bytes calldata command
    )
        external
        override
        onlyRole(KEEPER_ROLE)
        returns (int256 pnl, uint256 assetsOut)
    {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requireCommand(
            command,
            CrossChainTypes.CommandType.Harvest
        );
        (pnl, assetsOut) = _strategyAdapter.harvest(payload.params);

        if (assetsOut != 0) {
            idleAssets += assetsOut;
            _assertIdleAssetBalance();
            IERC20(asset).safeTransfer(VAULT, assetsOut);
            idleAssets -= assetsOut;
        }

        _markCommandExecuted(payload.opId, assetsOut);
        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function emergencyExit(
        bytes calldata command
    )
        external
        override
        onlyRole(GUARDIAN_ROLE)
        returns (uint256 assetsOut)
    {
        _requireConfigured();

        CrossChainTypes.CommandPayloadV1 memory payload = _requireCommand(
            command,
            CrossChainTypes.CommandType.EmergencyExit
        );
        assetsOut = _strategyAdapter.emergencyExit(payload.params);

        idleAssets += assetsOut;
        deployedAssets = 0;
        _assertIdleAssetBalance();

        if (assetsOut != 0) {
            IERC20(asset).safeTransfer(VAULT, assetsOut);
            idleAssets -= assetsOut;
        }

        _markCommandExecuted(payload.opId, assetsOut);
        emit CommandExecuted(payload.opId, STRATEGY_ID);
    }

    function previewStrategyReport(
        uint32 chainId,
        bytes32 positionsHash
    ) external view override returns (CrossChainTypes.StrategyReport memory report) {
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
        override
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
            revert LocalStrategyAgent__AssetNotConfigured();
        }
        if (address(_strategyAdapter) == address(0)) {
            revert LocalStrategyAgent__StrategyAdapterNotConfigured();
        }
    }

    function _decodeAndValidateCommand(
        bytes calldata payload
    ) internal view returns (CrossChainTypes.CommandPayloadV1 memory command) {
        command = abi.decode(payload, (CrossChainTypes.CommandPayloadV1));
        if (command.strategyId != STRATEGY_ID) {
            revert LocalStrategyAgent__InvalidStrategyId(command.strategyId);
        }
        if (
            command.commandType != CrossChainTypes.CommandType.Allocate &&
            command.commandType != CrossChainTypes.CommandType.Recall &&
            command.commandType != CrossChainTypes.CommandType.Harvest &&
            command.commandType != CrossChainTypes.CommandType.EmergencyExit
        ) {
            revert LocalStrategyAgent__UnsupportedCommandType(
                command.commandType
            );
        }
        _requireActiveDeadline(command.opId, command.deadline);
    }

    function _requireCommand(
        bytes calldata command,
        CrossChainTypes.CommandType expectedCommandType
    ) internal returns (CrossChainTypes.CommandPayloadV1 memory payload) {
        payload = _decodeAndValidateCommand(command);

        StoredCommand storage storedCommand = _commands[payload.opId];
        if (storedCommand.executedAt != 0) {
            revert LocalStrategyAgent__CommandAlreadyExecuted(payload.opId);
        }
        bytes32 payloadHash;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, command.offset, command.length)
            payloadHash := keccak256(ptr, command.length)
        }
        if (storedCommand.payloadHash != bytes32(0)) {
            if (storedCommand.payloadHash != payloadHash) {
                revert LocalStrategyAgent__PayloadMismatch(payload.opId);
            }
        } else {
            storedCommand.payloadHash = payloadHash;
            storedCommand.commandType = payload.commandType;
            storedCommand.assets = payload.assets;
            storedCommand.minAssetsOut = payload.minAssetsOut;
            storedCommand.deadline = payload.deadline;
        }
        if (storedCommand.commandType != expectedCommandType) {
            revert LocalStrategyAgent__UnsupportedCommandType(
                payload.commandType
            );
        }
    }

    function _markCommandExecuted(bytes32 opId, uint256 executedAssets) internal {
        StoredCommand storage command = _commands[opId];
        command.executedAt = uint64(block.timestamp);
        command.executedAssets = executedAssets;
    }

    function _requireActiveDeadline(bytes32 opId, uint64 deadline) internal view {
        // forge-lint: disable-next-line(block-timestamp)
        if (deadline < block.timestamp) {
            revert LocalStrategyAgent__DeadlineExpired(
                opId,
                deadline,
                uint64(block.timestamp)
            );
        }
    }

    function _assertIdleAssetBalance() internal view {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance < idleAssets) {
            revert LocalStrategyAgent__AssetBalanceInvariant(
                balance,
                idleAssets
            );
        }
    }

    function _buildStrategyReport(
        uint32 chainId,
        bytes32 positionsHash,
        uint64 reportTimestamp
    ) internal view returns (CrossChainTypes.StrategyReport memory report) {
        if (chainId == 0) {
            revert LocalStrategyAgent__InvalidReportChainId();
        }

        uint256 strategyValue = _strategyAdapter.totalValue();
        uint256 strategyFreeLiquidity = _strategyAdapter.freeLiquidity();
        if (strategyFreeLiquidity > strategyValue) {
            revert LocalStrategyAgent__InvalidReportLiquidity(
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

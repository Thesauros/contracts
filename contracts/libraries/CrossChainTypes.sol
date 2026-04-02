// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

library CrossChainTypes {
    enum StrategyKind {
        Undefined,
        Aave,
        Perpetual,
        Gmx,
        Custom
    }

    enum StrategyHealth {
        Undefined,
        Active,
        Paused,
        EmergencyExitOnly,
        Deprecated
    }

    enum OperationType {
        Allocate,
        Recall,
        Harvest,
        EmergencyExit
    }

    enum OperationStatus {
        Undefined,
        Created,
        Sent,
        Received,
        Executed,
        Settled,
        Cancelled,
        Failed
    }

    enum WithdrawalStatus {
        Undefined,
        Pending,
        Funded,
        Claimed,
        Cancelled
    }

    enum CommandType {
        Allocate,
        Recall,
        Harvest,
        EmergencyExit,
        Ack,
        Report
    }

    struct StrategyConfig {
        uint32 strategyId;
        uint32 chainId;
        address agent;
        address asset;
        uint96 debtLimit;
        uint96 maxSlippageBps;
        uint48 maxReportDelay;
        bool depositsEnabled;
        bool withdrawalsEnabled;
        bool emergencyExitOnly;
        StrategyKind kind;
    }

    struct StrategyState {
        uint256 currentDebt;
        uint256 lastReportedValue;
        uint256 pendingBridgeIn;
        uint256 pendingBridgeOut;
        uint256 freeLiquidity;
        uint256 unrealizedLossBuffer;
        uint64 lastReportTimestamp;
        uint64 lastAckTimestamp;
        StrategyHealth health;
    }

    struct Operation {
        bytes32 opId;
        uint32 strategyId;
        OperationType opType;
        uint256 assets;
        uint256 minAssetsOut;
        uint64 createdAt;
        uint64 deadline;
        OperationStatus status;
    }

    struct WithdrawalRequest {
        uint256 requestId;
        address owner;
        address receiver;
        uint256 shares;
        uint256 assetsPreview;
        uint64 createdAt;
        WithdrawalStatus status;
    }

    struct StrategyReport {
        uint32 strategyId;
        uint32 chainId;
        uint256 totalValue;
        uint256 freeLiquidity;
        uint256 totalDebt;
        int256 pnl;
        uint64 reportTimestamp;
        bytes32 positionsHash;
    }

    struct NavBuckets {
        uint256 homeIdle;
        uint256 localBufferAssets;
        uint256 settledStrategyValue;
        uint256 pendingBridgeIn;
        uint256 pendingBridgeOut;
        uint256 unrealizedLossBuffer;
        uint256 fundedWithdrawalObligations;
        uint256 availableHomeLiquidity;
        uint256 totalManagedAssets;
    }

    struct CommandPayloadV1 {
        uint8 version;
        bytes32 opId;
        uint32 strategyId;
        CommandType commandType;
        uint256 assets;
        uint64 commandTimestamp;
        bytes params;
    }
}

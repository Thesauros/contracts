// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {ICrossChainVault} from "../interfaces/crosschain/ICrossChainVault.sol";
import {ILocalStrategyAgent} from "../interfaces/crosschain/ILocalStrategyAgent.sol";
import {IReportSettler} from "../interfaces/crosschain/IReportSettler.sol";
import {IStrategyAllocator} from "../interfaces/crosschain/IStrategyAllocator.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
import {IWithdrawalQueue} from "../interfaces/crosschain/IWithdrawalQueue.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract CrossChainVault is
    ERC4626,
    ERC20Permit,
    CrossChainAccessControl,
    ICrossChainVault
{
    using SafeERC20 for IERC20;

    error CrossChainVault__ZeroAddress();
    error CrossChainVault__InvalidShares();
    error CrossChainVault__InsufficientHomeLiquidity();
    error CrossChainVault__StrategyReportAlreadySettled();
    error CrossChainVault__StaleStrategyReport(uint32 strategyId);
    error CrossChainVault__UseInstantWithdraw();
    error CrossChainVault__InvalidWithdrawalStatus();
    error CrossChainVault__InsufficientReceivedAssets();
    error CrossChainVault__UnauthorizedClaim();
    error CrossChainVault__FundedWithdrawalAccountingMismatch();
    error CrossChainVault__OperationAccountingAlreadySynced(bytes32 opId);
    error CrossChainVault__UnsupportedOperationType();
    error CrossChainVault__UnsupportedOperationStatus(
        bytes32 opId,
        CrossChainTypes.OperationStatus status
    );
    error CrossChainVault__InsufficientStrategyDebt(
        uint32 strategyId,
        uint256 currentDebt,
        uint256 requiredDebt
    );
    error CrossChainVault__InsufficientPendingBridgeOut(
        uint32 strategyId,
        uint256 pendingBridgeOut,
        uint256 requiredPendingBridgeOut
    );
    error CrossChainVault__InsufficientPendingBridgeIn(
        uint32 strategyId,
        uint256 pendingBridgeIn,
        uint256 requiredPendingBridgeIn
    );
    error CrossChainVault__DelayedFundingPaused();
    error CrossChainVault__InsufficientInstantLiquidity();
    error CrossChainVault__UnauthorizedCancellation();
    error CrossChainVault__NonLocalStrategy(uint32 strategyId, uint256 chainId);
    error CrossChainVault__InvalidLocalAgent(uint32 strategyId);
    error CrossChainVault__InvalidLocalOperationStatus(
        bytes32 opId,
        CrossChainTypes.OperationStatus status
    );

    uint256 private immutable ENTRY_CHAIN_ID;
    uint256 public override homeIdle;
    uint256 public override targetLocalBufferAssets;
    uint256 public override minimumResidualLiquidity;
    uint256 public override fundedWithdrawalObligations;
    uint64 public override normalRedemptionSla = 15 minutes;
    uint64 public override degradedRedemptionSla = 60 minutes;
    bool public override delayedFundingPaused;
    bool private _manualDegradedRedemptionMode;

    IStrategyRegistry private immutable STRATEGY_REGISTRY;
    IStrategyAllocator private immutable STRATEGY_ALLOCATOR;
    IReportSettler private immutable REPORT_SETTLER;
    IWithdrawalQueue private immutable WITHDRAWAL_QUEUE;
    mapping(bytes32 opId => CrossChainTypes.OperationStatus)
        private _accountedOperationStatuses;

    event StrategyReportSettled(
        uint32 indexed strategyId,
        uint256 totalValue,
        uint256 freeLiquidity,
        uint256 totalDebt,
        uint64 reportTimestamp
    );
    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed owner,
        address indexed receiver,
        uint256 shares,
        uint256 assetsPreview
    );
    event WithdrawalClaimed(
        uint256 indexed requestId,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );
    event WithdrawalFunded(
        uint256 indexed requestId,
        uint256 assetsReserved,
        uint256 fundedObligationsAfter
    );
    event LocalBufferTargetUpdated(
        uint256 previousTarget,
        uint256 newTarget,
        uint256 effectiveLocalBufferAssets
    );
    event MinimumResidualLiquidityUpdated(
        uint256 previousMinimum,
        uint256 newMinimum
    );
    event RedemptionSlaUpdated(
        uint64 previousNormalSla,
        uint64 previousDegradedSla,
        uint64 newNormalSla,
        uint64 newDegradedSla
    );
    event DegradedRedemptionModeUpdated(bool enabled);
    event DelayedFundingPauseUpdated(bool paused);
    event WithdrawalFundingStarted(
        uint256 indexed requestId,
        uint256 assetsPreview,
        uint64 targetSla,
        CrossChainTypes.RedemptionMode mode
    );
    event WithdrawalCancelled(
        uint256 indexed requestId,
        address indexed owner,
        uint256 sharesReturned
    );
    event EntryBoundaryConfirmed(
        uint256 indexed entryChainId,
        bool finalEntryVault,
        bool accountingCore
    );
    event OperationAccountingSynced(
        bytes32 indexed opId,
        uint32 indexed strategyId,
        CrossChainTypes.OperationType opType,
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.OperationStatus currentStatus
    );
    event RecallFundsReceived(uint256 assets, uint256 homeIdleAfter);
    event LocalStrategyAssetsReceived(
        uint32 indexed strategyId,
        uint256 assets,
        uint256 homeIdleAfter
    );

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address admin,
        IStrategyRegistry strategyRegistry_,
        IStrategyAllocator strategyAllocator_,
        IReportSettler reportSettler_,
        IWithdrawalQueue withdrawalQueue_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        ERC4626(asset_)
        CrossChainAccessControl(admin)
    {
        if (
            address(asset_) == address(0) ||
            admin == address(0) ||
            address(strategyRegistry_) == address(0) ||
            address(strategyAllocator_) == address(0) ||
            address(reportSettler_) == address(0) ||
            address(withdrawalQueue_) == address(0)
        ) {
            revert CrossChainVault__ZeroAddress();
        }

        ENTRY_CHAIN_ID = block.chainid;
        STRATEGY_REGISTRY = strategyRegistry_;
        STRATEGY_ALLOCATOR = strategyAllocator_;
        REPORT_SETTLER = reportSettler_;
        WITHDRAWAL_QUEUE = withdrawalQueue_;

        emit EntryBoundaryConfirmed(ENTRY_CHAIN_ID, true, true);
    }

    function entryChainId() public view returns (uint256) {
        return ENTRY_CHAIN_ID;
    }

    function strategyRegistry()
        public
        view
        override
        returns (IStrategyRegistry)
    {
        return STRATEGY_REGISTRY;
    }

    function strategyAllocator()
        public
        view
        override
        returns (IStrategyAllocator)
    {
        return STRATEGY_ALLOCATOR;
    }

    function reportSettler()
        public
        view
        override
        returns (IReportSettler)
    {
        return REPORT_SETTLER;
    }

    function withdrawalQueue()
        public
        view
        override
        returns (IWithdrawalQueue)
    {
        return WITHDRAWAL_QUEUE;
    }

    function availableHomeLiquidity() public view override returns (uint256) {
        return _availableHomeLiquidity();
    }

    /// @dev Routing helper for off-chain policy. This is intentionally conservative and does not
    ///      attempt to model bridge latency or strategy liquidity; it only answers whether the
    ///      system is visibility-degraded due to stale reports.
    function hasStaleStrategyReports() external view returns (bool) {
        return _hasStaleStrategyReports();
    }

    /// @dev Routing helper for off-chain policy: maximum assets that can be allocated while
    ///      preserving the local buffer target and residual liquidity floor.
    function maxAllocatableAssets() external view returns (uint256) {
        uint256 liquidAssets = _availableHomeLiquidity();

        uint256 required = minimumResidualLiquidity;
        if (targetLocalBufferAssets > required) {
            required = targetLocalBufferAssets;
        }

        if (liquidAssets <= required) {
            return 0;
        }

        return liquidAssets - required;
    }

    function instantWithdrawalCapacity()
        public
        view
        override
        returns (uint256)
    {
        uint256 liquidAssets = _availableHomeLiquidity();
        if (liquidAssets <= minimumResidualLiquidity) {
            return 0;
        }

        return liquidAssets - minimumResidualLiquidity;
    }

    function currentRedemptionMode()
        public
        view
        override
        returns (CrossChainTypes.RedemptionMode)
    {
        if (_manualDegradedRedemptionMode || _hasStaleStrategyReports()) {
            return CrossChainTypes.RedemptionMode.Degraded;
        }

        return CrossChainTypes.RedemptionMode.Normal;
    }

    function currentRedemptionSla()
        public
        view
        override
        returns (uint64)
    {
        if (
            currentRedemptionMode() == CrossChainTypes.RedemptionMode.Degraded
        ) {
            return degradedRedemptionSla;
        }

        return normalRedemptionSla;
    }

    function positionView(
        address owner
    ) public view returns (CrossChainTypes.EntryPosition memory position) {
        position.shares = balanceOf(owner);
        position.assetEquivalent = previewRedeem(position.shares);
        position.maxInstantWithdrawAssets = maxWithdraw(owner);
        position.maxInstantRedeemShares = maxRedeem(owner);
    }

    function navBuckets()
        public
        view
        override
        returns (CrossChainTypes.NavBuckets memory buckets)
    {
        buckets.homeIdle = homeIdle;
        buckets.localBufferAssets = _localBufferAssets();
        buckets.fundedWithdrawalObligations = fundedWithdrawalObligations;

        uint256 count = STRATEGY_REGISTRY.strategyCount();
        for (uint256 i; i < count; ++i) {
            uint32 strategyId = STRATEGY_REGISTRY.strategyIdAt(i);
            CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
                .getStrategyState(strategyId);

            buckets.settledStrategyValue += state.lastReportedValue;
            buckets.pendingBridgeIn += state.pendingBridgeIn;
            buckets.pendingBridgeOut += state.pendingBridgeOut;
            buckets.unrealizedLossBuffer += state.unrealizedLossBuffer;
        }

        buckets.availableHomeLiquidity = _availableHomeLiquidity();
        buckets.totalManagedAssets =
            buckets.homeIdle +
            buckets.settledStrategyValue +
            buckets.pendingBridgeIn +
            buckets.pendingBridgeOut -
            buckets.unrealizedLossBuffer;
    }

    function totalAssets()
        public
        view
        override(ERC4626, IERC4626)
        returns (uint256 assets)
    {
        assets = navBuckets().totalManagedAssets;
    }

    function maxWithdraw(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        if (_hasStaleStrategyReports()) {
            return 0;
        }

        uint256 ownerAssets = super.maxWithdraw(owner);
        uint256 liquidAssets = instantWithdrawalCapacity();
        return ownerAssets < liquidAssets ? ownerAssets : liquidAssets;
    }

    function maxRedeem(
        address owner
    ) public view override(ERC4626, IERC4626) returns (uint256) {
        if (_hasStaleStrategyReports()) {
            return 0;
        }

        uint256 ownerShares = balanceOf(owner);
        uint256 liquidShares = _convertToShares(
            instantWithdrawalCapacity(),
            Math.Rounding.Floor
        );

        return ownerShares < liquidShares ? ownerShares : liquidShares;
    }

    function decimals()
        public
        view
        override(ERC20, ERC4626, IERC20Metadata)
        returns (uint8)
    {
        return super.decimals();
    }

    function requestWithdrawal(
        uint256 shares,
        address receiver,
        address owner
    ) external override returns (uint256 requestId, uint256 assetsPreview) {
        if (receiver == address(0) || owner == address(0)) {
            revert CrossChainVault__ZeroAddress();
        }
        if (shares == 0) {
            revert CrossChainVault__InvalidShares();
        }

        _assertNoStaleStrategyReports();

        assetsPreview = previewRedeem(shares);
        if (assetsPreview <= instantWithdrawalCapacity()) {
            revert CrossChainVault__UseInstantWithdraw();
        }

        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        _transfer(owner, address(this), shares);

        requestId = WITHDRAWAL_QUEUE.queueWithdrawal(
            owner,
            receiver,
            shares,
            assetsPreview
        );

        emit WithdrawalRequested(
            requestId,
            owner,
            receiver,
            shares,
            assetsPreview
        );
    }

    function startWithdrawalFunding(uint256 requestId) external override {
        _requireKeeperOrGovernance();

        if (delayedFundingPaused) {
            revert CrossChainVault__DelayedFundingPaused();
        }

        CrossChainTypes.WithdrawalRequest memory request = WITHDRAWAL_QUEUE
            .getWithdrawalRequest(requestId);
        if (request.status != CrossChainTypes.WithdrawalStatus.Pending) {
            revert CrossChainVault__InvalidWithdrawalStatus();
        }

        WITHDRAWAL_QUEUE.setWithdrawalStatus(
            requestId,
            CrossChainTypes.WithdrawalStatus.Processing
        );

        emit WithdrawalFundingStarted(
            requestId,
            request.assetsPreview,
            currentRedemptionSla(),
            currentRedemptionMode()
        );
    }

    function fundWithdrawal(uint256 requestId) external override {
        _requireKeeperOrGovernance();

        if (delayedFundingPaused) {
            revert CrossChainVault__DelayedFundingPaused();
        }

        CrossChainTypes.WithdrawalRequest memory request = WITHDRAWAL_QUEUE
            .getWithdrawalRequest(requestId);
        if (
            request.status != CrossChainTypes.WithdrawalStatus.Pending &&
            request.status != CrossChainTypes.WithdrawalStatus.Processing
        ) {
            revert CrossChainVault__InvalidWithdrawalStatus();
        }
        if (request.assetsPreview > instantWithdrawalCapacity()) {
            revert CrossChainVault__InsufficientInstantLiquidity();
        }

        fundedWithdrawalObligations += request.assetsPreview;
        WITHDRAWAL_QUEUE.setWithdrawalStatus(
            requestId,
            CrossChainTypes.WithdrawalStatus.Funded
        );

        emit WithdrawalFunded(
            requestId,
            request.assetsPreview,
            fundedWithdrawalObligations
        );
    }

    function cancelWithdrawal(uint256 requestId) external override {
        CrossChainTypes.WithdrawalRequest memory request = WITHDRAWAL_QUEUE
            .getWithdrawalRequest(requestId);
        if (
            request.status != CrossChainTypes.WithdrawalStatus.Pending &&
            request.status != CrossChainTypes.WithdrawalStatus.Processing
        ) {
            revert CrossChainVault__InvalidWithdrawalStatus();
        }
        if (
            _msgSender() != request.owner &&
            !hasRole(KEEPER_ROLE, _msgSender()) &&
            !hasRole(GOVERNANCE_ROLE, _msgSender())
        ) {
            revert CrossChainVault__UnauthorizedCancellation();
        }

        WITHDRAWAL_QUEUE.setWithdrawalStatus(
            requestId,
            CrossChainTypes.WithdrawalStatus.Cancelled
        );
        _transfer(address(this), request.owner, request.shares);

        emit WithdrawalCancelled(requestId, request.owner, request.shares);
    }

    function claimWithdrawal(
        uint256 requestId
    ) external override returns (uint256 assets) {
        CrossChainTypes.WithdrawalRequest memory request = WITHDRAWAL_QUEUE
            .getWithdrawalRequest(requestId);
        if (request.status != CrossChainTypes.WithdrawalStatus.Funded) {
            revert CrossChainVault__InvalidWithdrawalStatus();
        }
        if (
            _msgSender() != request.owner && _msgSender() != request.receiver
        ) {
            revert CrossChainVault__UnauthorizedClaim();
        }
        if (request.assetsPreview > homeIdle) {
            revert CrossChainVault__InsufficientHomeLiquidity();
        }
        if (request.assetsPreview > fundedWithdrawalObligations) {
            revert CrossChainVault__FundedWithdrawalAccountingMismatch();
        }

        assets = request.assetsPreview;
        fundedWithdrawalObligations -= assets;
        homeIdle -= assets;

        WITHDRAWAL_QUEUE.setWithdrawalStatus(
            requestId,
            CrossChainTypes.WithdrawalStatus.Claimed
        );

        _burn(address(this), request.shares);
        IERC20(asset()).safeTransfer(request.receiver, assets);

        emit Withdraw(
            _msgSender(),
            request.receiver,
            request.owner,
            assets,
            request.shares
        );
        emit WithdrawalClaimed(
            requestId,
            request.receiver,
            assets,
            request.shares
        );
    }

    function settleStrategyReport(uint32 strategyId) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
            .getStrategyState(strategyId);
        CrossChainTypes.StrategyReport memory report = REPORT_SETTLER
            .getLastReport(strategyId);

        if (report.reportTimestamp <= state.lastReportTimestamp) {
            revert CrossChainVault__StrategyReportAlreadySettled();
        }

        state.lastReportedValue = report.totalValue;
        state.freeLiquidity = report.freeLiquidity;
        state.currentDebt = report.totalDebt;
        state.lastReportTimestamp = report.reportTimestamp;

        STRATEGY_REGISTRY.setStrategyState(strategyId, state);

        emit StrategyReportSettled(
            strategyId,
            report.totalValue,
            report.freeLiquidity,
            report.totalDebt,
            report.reportTimestamp
        );
    }

    function setTargetLocalBufferAssets(
        uint256 assets
    ) external override onlyRole(GOVERNANCE_ROLE) {
        uint256 previousTarget = targetLocalBufferAssets;
        targetLocalBufferAssets = assets;

        emit LocalBufferTargetUpdated(
            previousTarget,
            assets,
            _localBufferAssets()
        );
    }

    function setMinimumResidualLiquidity(
        uint256 assets
    ) external override onlyRole(GOVERNANCE_ROLE) {
        uint256 previousMinimum = minimumResidualLiquidity;
        minimumResidualLiquidity = assets;

        emit MinimumResidualLiquidityUpdated(previousMinimum, assets);
    }

    function setRedemptionSla(
        uint64 normalModeSla,
        uint64 degradedModeSla
    ) external override onlyRole(GOVERNANCE_ROLE) {
        uint64 previousNormalSla = normalRedemptionSla;
        uint64 previousDegradedSla = degradedRedemptionSla;

        normalRedemptionSla = normalModeSla;
        degradedRedemptionSla = degradedModeSla;

        emit RedemptionSlaUpdated(
            previousNormalSla,
            previousDegradedSla,
            normalModeSla,
            degradedModeSla
        );
    }

    function setDegradedRedemptionMode(
        bool enabled
    ) external override onlyRole(GOVERNANCE_ROLE) {
        _manualDegradedRedemptionMode = enabled;
        emit DegradedRedemptionModeUpdated(enabled);
    }

    function setDelayedFundingPaused(
        bool paused
    ) external override onlyRole(GOVERNANCE_ROLE) {
        delayedFundingPaused = paused;
        emit DelayedFundingPauseUpdated(paused);
    }

    function syncOperationAccounting(bytes32 opId) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.Operation memory operation = STRATEGY_ALLOCATOR
            .getOperation(opId);
        CrossChainTypes.OperationStatus previousStatus = _accountedOperationStatuses[
            opId
        ];
        if (previousStatus == operation.status) {
            revert CrossChainVault__OperationAccountingAlreadySynced(opId);
        }

        CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
            .getStrategyState(operation.strategyId);

        if (operation.opType == CrossChainTypes.OperationType.Allocate) {
            _syncAllocateAccounting(operation, previousStatus, state);
        } else if (operation.opType == CrossChainTypes.OperationType.Recall) {
            _syncRecallAccounting(operation, previousStatus, state);
        } else {
            revert CrossChainVault__UnsupportedOperationType();
        }

        STRATEGY_REGISTRY.setStrategyState(operation.strategyId, state);
        _accountedOperationStatuses[opId] = operation.status;

        emit OperationAccountingSynced(
            opId,
            operation.strategyId,
            operation.opType,
            previousStatus,
            operation.status
        );
    }

    function executeLocalAllocate(
        bytes32 opId,
        bytes calldata params
    ) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.Operation memory operation = STRATEGY_ALLOCATOR
            .getOperation(opId);
        if (operation.opType != CrossChainTypes.OperationType.Allocate) {
            revert CrossChainVault__UnsupportedOperationType();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(operation.strategyId);
        _requireLocalStrategy(config);
        _requireLocalOperationStatus(opId, operation.status);

        bytes memory payload = STRATEGY_ALLOCATOR.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            params
        );

        IERC20(asset()).safeTransfer(config.agent, operation.assets);
        ILocalStrategyAgent(config.agent).executeAllocate(payload);
    }

    function executeLocalRecall(
        bytes32 opId,
        bytes calldata params
    ) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.Operation memory operation = STRATEGY_ALLOCATOR
            .getOperation(opId);
        if (operation.opType != CrossChainTypes.OperationType.Recall) {
            revert CrossChainVault__UnsupportedOperationType();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(operation.strategyId);
        _requireLocalStrategy(config);
        _requireLocalOperationStatus(opId, operation.status);

        bytes memory payload = STRATEGY_ALLOCATOR.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            params
        );

        uint256 assetsFreed = ILocalStrategyAgent(config.agent).executeRecall(
            payload
        );
        if (assetsFreed != 0) {
            _recordInboundAssets(assetsFreed);
            emit LocalStrategyAssetsReceived(
                operation.strategyId,
                assetsFreed,
                homeIdle
            );
        }
    }

    function executeLocalHarvest(
        bytes32 opId,
        bytes calldata params
    ) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.Operation memory operation = STRATEGY_ALLOCATOR
            .getOperation(opId);
        if (operation.opType != CrossChainTypes.OperationType.Harvest) {
            revert CrossChainVault__UnsupportedOperationType();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(operation.strategyId);
        _requireLocalStrategy(config);
        _requireLocalOperationStatus(opId, operation.status);

        bytes memory payload = STRATEGY_ALLOCATOR.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            params
        );

        (, uint256 assetsOut) = ILocalStrategyAgent(config.agent).harvest(
            payload
        );
        if (assetsOut != 0) {
            _recordInboundAssets(assetsOut);
            emit LocalStrategyAssetsReceived(
                operation.strategyId,
                assetsOut,
                homeIdle
            );
        }
    }

    function executeLocalEmergencyExit(
        bytes32 opId,
        bytes calldata params
    ) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.Operation memory operation = STRATEGY_ALLOCATOR
            .getOperation(opId);
        if (operation.opType != CrossChainTypes.OperationType.EmergencyExit) {
            revert CrossChainVault__UnsupportedOperationType();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(operation.strategyId);
        _requireLocalStrategy(config);
        _requireLocalOperationStatus(opId, operation.status);

        bytes memory payload = STRATEGY_ALLOCATOR.encodeCommandPayload(
            opId,
            uint64(block.timestamp),
            params
        );

        uint256 assetsOut = ILocalStrategyAgent(config.agent).emergencyExit(
            payload
        );
        if (assetsOut != 0) {
            _recordInboundAssets(assetsOut);
            emit LocalStrategyAssetsReceived(
                operation.strategyId,
                assetsOut,
                homeIdle
            );
        }
    }

    function receiveRecallFunds(uint256 assets) external override {
        _requireBridgeKeeperOrGovernance();
        _recordInboundAssets(assets);
        emit RecallFundsReceived(assets, homeIdle);
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);
        homeIdle += assets;
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        _assertNoStaleStrategyReports();

        if (assets > homeIdle) {
            revert CrossChainVault__InsufficientHomeLiquidity();
        }
        if (assets > _availableHomeLiquidity()) {
            revert CrossChainVault__InsufficientHomeLiquidity();
        }

        homeIdle -= assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function _hasStaleStrategyReports() internal view returns (bool) {
        uint256 count = STRATEGY_REGISTRY.strategyCount();
        for (uint256 i; i < count; ++i) {
            uint32 strategyId = STRATEGY_REGISTRY.strategyIdAt(i);
            CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
                .getStrategyConfig(strategyId);
            CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
                .getStrategyState(strategyId);

            if (!_strategyHasExposure(state)) {
                continue;
            }

            if (
                config.maxReportDelay != 0 &&
                (state.lastReportTimestamp == 0 ||
                    block.timestamp >
                    uint256(state.lastReportTimestamp) + config.maxReportDelay)
            ) {
                return true;
            }
        }

        return false;
    }

    function _assertNoStaleStrategyReports() internal view {
        uint256 count = STRATEGY_REGISTRY.strategyCount();
        for (uint256 i; i < count; ++i) {
            uint32 strategyId = STRATEGY_REGISTRY.strategyIdAt(i);
            CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
                .getStrategyConfig(strategyId);
            CrossChainTypes.StrategyState memory state = STRATEGY_REGISTRY
                .getStrategyState(strategyId);

            if (!_strategyHasExposure(state)) {
                continue;
            }

            if (
                config.maxReportDelay != 0 &&
                (state.lastReportTimestamp == 0 ||
                    block.timestamp >
                    uint256(state.lastReportTimestamp) + config.maxReportDelay)
            ) {
                revert CrossChainVault__StaleStrategyReport(strategyId);
            }
        }
    }

    function _strategyHasExposure(
        CrossChainTypes.StrategyState memory state
    ) internal pure returns (bool) {
        return
            state.currentDebt != 0 ||
            state.pendingBridgeIn != 0 ||
            state.pendingBridgeOut != 0 ||
            state.lastReportedValue != 0;
    }

    function _requireKeeperOrGovernance() internal view {
        if (
            !hasRole(KEEPER_ROLE, _msgSender()) &&
            !hasRole(GOVERNANCE_ROLE, _msgSender())
        ) {
            revert AccessControlUnauthorizedAccount(_msgSender(), KEEPER_ROLE);
        }
    }

    function _requireBridgeKeeperOrGovernance() internal view {
        if (
            !hasRole(BRIDGE_ROLE, _msgSender()) &&
            !hasRole(KEEPER_ROLE, _msgSender()) &&
            !hasRole(GOVERNANCE_ROLE, _msgSender())
        ) {
            revert AccessControlUnauthorizedAccount(_msgSender(), BRIDGE_ROLE);
        }
    }

    function _recordInboundAssets(uint256 assets) internal {
        uint256 accountedBalance = IERC20(asset()).balanceOf(address(this));
        if (accountedBalance < homeIdle + assets) {
            revert CrossChainVault__InsufficientReceivedAssets();
        }

        homeIdle += assets;
    }

    function _requireLocalStrategy(
        CrossChainTypes.StrategyConfig memory config
    ) internal view {
        if (config.chainId != uint32(block.chainid)) {
            revert CrossChainVault__NonLocalStrategy(
                config.strategyId,
                config.chainId
            );
        }
        if (config.agent == address(0)) {
            revert CrossChainVault__InvalidLocalAgent(config.strategyId);
        }
    }

    function _requireLocalOperationStatus(
        bytes32 opId,
        CrossChainTypes.OperationStatus status
    ) internal pure {
        if (
            status != CrossChainTypes.OperationStatus.Sent &&
            status != CrossChainTypes.OperationStatus.Received
        ) {
            revert CrossChainVault__InvalidLocalOperationStatus(opId, status);
        }
    }

    function _syncAllocateAccounting(
        CrossChainTypes.Operation memory operation,
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.StrategyState memory state
    ) internal {
        if (
            _statusReached(previousStatus, operation.status, CrossChainTypes.OperationStatus.Sent)
        ) {
            if (operation.assets > _availableHomeLiquidity()) {
                revert CrossChainVault__InsufficientHomeLiquidity();
            }

            homeIdle -= operation.assets;
            state.pendingBridgeOut += operation.assets;
        }

        if (
            _statusReached(previousStatus, operation.status, CrossChainTypes.OperationStatus.Settled)
        ) {
            if (state.pendingBridgeOut < operation.assets) {
                revert CrossChainVault__InsufficientPendingBridgeOut(
                    operation.strategyId,
                    state.pendingBridgeOut,
                    operation.assets
                );
            }

            state.pendingBridgeOut -= operation.assets;
            state.currentDebt += operation.assets;
        }

        if (
            !_isSupportedAccountingStatus(operation.status)
        ) {
            revert CrossChainVault__UnsupportedOperationStatus(
                operation.opId,
                operation.status
            );
        }
    }

    function _syncRecallAccounting(
        CrossChainTypes.Operation memory operation,
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.StrategyState memory state
    ) internal pure {
        if (
            _statusReached(previousStatus, operation.status, CrossChainTypes.OperationStatus.Executed)
        ) {
            if (state.currentDebt < operation.assets) {
                revert CrossChainVault__InsufficientStrategyDebt(
                    operation.strategyId,
                    state.currentDebt,
                    operation.assets
                );
            }

            state.currentDebt -= operation.assets;
            state.pendingBridgeIn += operation.assets;
        }

        if (
            _statusReached(previousStatus, operation.status, CrossChainTypes.OperationStatus.Settled)
        ) {
            if (state.pendingBridgeIn < operation.assets) {
                revert CrossChainVault__InsufficientPendingBridgeIn(
                    operation.strategyId,
                    state.pendingBridgeIn,
                    operation.assets
                );
            }

            state.pendingBridgeIn -= operation.assets;
        }

        if (
            !_isSupportedAccountingStatus(operation.status)
        ) {
            revert CrossChainVault__UnsupportedOperationStatus(
                operation.opId,
                operation.status
            );
        }
    }

    function _availableHomeLiquidity() internal view returns (uint256) {
        if (fundedWithdrawalObligations >= homeIdle) {
            return 0;
        }

        return homeIdle - fundedWithdrawalObligations;
    }

    function _localBufferAssets() internal view returns (uint256) {
        return
            homeIdle < targetLocalBufferAssets
                ? homeIdle
                : targetLocalBufferAssets;
    }

    function _statusReached(
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.OperationStatus currentStatus,
        CrossChainTypes.OperationStatus checkpoint
    ) internal pure returns (bool) {
        return
            uint8(previousStatus) < uint8(checkpoint) &&
            uint8(currentStatus) >= uint8(checkpoint);
    }

    function _isSupportedAccountingStatus(
        CrossChainTypes.OperationStatus status
    ) internal pure returns (bool) {
        return
            status == CrossChainTypes.OperationStatus.Created ||
            status == CrossChainTypes.OperationStatus.Sent ||
            status == CrossChainTypes.OperationStatus.Received ||
            status == CrossChainTypes.OperationStatus.Executed ||
            status == CrossChainTypes.OperationStatus.Settled;
    }
}

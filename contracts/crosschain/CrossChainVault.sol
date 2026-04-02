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

    uint256 public override homeIdle;
    uint256 public override fundedWithdrawalObligations;

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
    event OperationAccountingSynced(
        bytes32 indexed opId,
        uint32 indexed strategyId,
        CrossChainTypes.OperationType opType,
        CrossChainTypes.OperationStatus previousStatus,
        CrossChainTypes.OperationStatus currentStatus
    );
    event RecallFundsReceived(uint256 assets, uint256 homeIdleAfter);

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

        STRATEGY_REGISTRY = strategyRegistry_;
        STRATEGY_ALLOCATOR = strategyAllocator_;
        REPORT_SETTLER = reportSettler_;
        WITHDRAWAL_QUEUE = withdrawalQueue_;
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

    function navBuckets()
        public
        view
        override
        returns (CrossChainTypes.NavBuckets memory buckets)
    {
        buckets.homeIdle = homeIdle;
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
        uint256 liquidAssets = _availableHomeLiquidity();
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
            _availableHomeLiquidity(),
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
        if (assetsPreview <= _availableHomeLiquidity()) {
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

    function fundWithdrawal(uint256 requestId) external override {
        _requireKeeperOrGovernance();

        CrossChainTypes.WithdrawalRequest memory request = WITHDRAWAL_QUEUE
            .getWithdrawalRequest(requestId);
        if (request.status != CrossChainTypes.WithdrawalStatus.Pending) {
            revert CrossChainVault__InvalidWithdrawalStatus();
        }
        if (request.assetsPreview > _availableHomeLiquidity()) {
            revert CrossChainVault__InsufficientHomeLiquidity();
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

    function receiveRecallFunds(uint256 assets) external override {
        _requireBridgeKeeperOrGovernance();

        uint256 accountedBalance = IERC20(asset()).balanceOf(address(this));
        if (accountedBalance < homeIdle + assets) {
            revert CrossChainVault__InsufficientReceivedAssets();
        }

        homeIdle += assets;
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

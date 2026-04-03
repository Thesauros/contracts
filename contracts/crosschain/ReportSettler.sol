// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IReportSettler} from "../interfaces/crosschain/IReportSettler.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract ReportSettler is CrossChainAccessControl, IReportSettler {
    error ReportSettler__UnknownStrategy();
    error ReportSettler__ChainMismatch();
    error ReportSettler__ReportOutdated();
    error ReportSettler__ReportStale();

    IStrategyRegistry private immutable STRATEGY_REGISTRY;

    mapping(uint32 strategyId => CrossChainTypes.StrategyReport) private _reports;

    constructor(
        address admin,
        IStrategyRegistry strategyRegistry_
    ) CrossChainAccessControl(admin) {
        STRATEGY_REGISTRY = strategyRegistry_;
    }

    function strategyRegistry() public view returns (IStrategyRegistry) {
        return STRATEGY_REGISTRY;
    }

    function submitReport(
        CrossChainTypes.StrategyReport calldata report
    ) external onlyRole(REPORTER_ROLE) {
        if (!STRATEGY_REGISTRY.strategyExists(report.strategyId)) {
            revert ReportSettler__UnknownStrategy();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(report.strategyId);
        CrossChainTypes.StrategyReport memory previous = _reports[
            report.strategyId
        ];

        if (config.chainId != report.chainId) {
            revert ReportSettler__ChainMismatch();
        }
        if (report.reportTimestamp <= previous.reportTimestamp) {
            revert ReportSettler__ReportOutdated();
        }
        if (
            config.maxReportDelay != 0 &&
            block.timestamp > uint256(report.reportTimestamp) + config.maxReportDelay
        ) {
            revert ReportSettler__ReportStale();
        }

        _reports[report.strategyId] = report;

        emit StrategyReportAccepted(
            report.strategyId,
            report.totalValue,
            report.freeLiquidity,
            report.reportTimestamp,
            report.positionsHash
        );
    }

    function getLastReport(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyReport memory) {
        return _reports[strategyId];
    }
}

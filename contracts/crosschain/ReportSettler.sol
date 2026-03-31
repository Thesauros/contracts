// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IReportSettler} from "../interfaces/crosschain/IReportSettler.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract ReportSettler is CrossChainAccessControl, IReportSettler {
    error ReportSettler__UnknownStrategy();
    error ReportSettler__ChainMismatch();
    error ReportSettler__ReportOutdated();

    IStrategyRegistry public immutable strategyRegistry;

    mapping(uint32 strategyId => CrossChainTypes.StrategyReport) private _reports;

    constructor(
        address admin,
        IStrategyRegistry strategyRegistry_
    ) CrossChainAccessControl(admin) {
        strategyRegistry = strategyRegistry_;
    }

    function submitReport(
        CrossChainTypes.StrategyReport calldata report
    ) external onlyRole(REPORTER_ROLE) {
        if (!strategyRegistry.strategyExists(report.strategyId)) {
            revert ReportSettler__UnknownStrategy();
        }

        CrossChainTypes.StrategyConfig memory config = strategyRegistry
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

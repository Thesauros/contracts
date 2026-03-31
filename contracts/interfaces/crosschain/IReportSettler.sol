// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IReportSettler {
    event StrategyReportAccepted(
        uint32 indexed strategyId,
        uint256 totalValue,
        uint256 freeLiquidity,
        uint64 reportTimestamp,
        bytes32 positionsHash
    );

    function submitReport(
        CrossChainTypes.StrategyReport calldata report
    ) external;

    function getLastReport(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyReport memory);
}

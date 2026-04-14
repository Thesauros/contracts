// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IReportSettler} from "../interfaces/crosschain/IReportSettler.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ReportSettler is CrossChainAccessControl, IReportSettler, EIP712 {
    error ReportSettler__UnknownStrategy();
    error ReportSettler__ChainMismatch();
    error ReportSettler__ReportOutdated();
    error ReportSettler__ReportStale();
    error ReportSettler__InvalidAttestation();
    error ReportSettler__AttestorNotAuthorized();
    error ReportSettler__AttestationRequired();

    event AttestationRequirementUpdated(bool required);

    IStrategyRegistry private immutable STRATEGY_REGISTRY;

    bool public attestationRequired;

    mapping(uint32 strategyId => CrossChainTypes.StrategyReport) private _reports;

    bytes32 private constant REPORT_TYPEHASH =
        keccak256(
            "StrategyReport(uint32 strategyId,uint32 chainId,uint256 totalValue,uint256 freeLiquidity,uint256 totalDebt,int256 pnl,uint64 reportTimestamp,bytes32 positionsHash)"
        );

    constructor(
        address admin,
        IStrategyRegistry strategyRegistry_
    ) CrossChainAccessControl(admin) EIP712("CrossChainVaultReport", "1") {
        STRATEGY_REGISTRY = strategyRegistry_;
    }

    function strategyRegistry() public view returns (IStrategyRegistry) {
        return STRATEGY_REGISTRY;
    }

    function submitReport(
        CrossChainTypes.StrategyReport calldata report
    ) external onlyRole(REPORTER_ROLE) {
        if (attestationRequired) {
            revert ReportSettler__AttestationRequired();
        }
        _acceptReport(report);
    }

    function submitReportAttested(
        CrossChainTypes.StrategyReport calldata report,
        bytes calldata signature
    ) external {
        bytes32 digest = _hashTypedDataV4(_hashReport(report));
        address attestor = ECDSA.recover(digest, signature);

        if (attestor == address(0)) {
            revert ReportSettler__InvalidAttestation();
        }
        if (!hasRole(REPORT_ATTESTOR_ROLE, attestor)) {
            revert ReportSettler__AttestorNotAuthorized();
        }

        _acceptReport(report);
    }

    function setAttestationRequired(bool required) external onlyRole(GOVERNANCE_ROLE) {
        attestationRequired = required;
        emit AttestationRequirementUpdated(required);
    }

    function reportDigest(
        CrossChainTypes.StrategyReport calldata report
    ) external view returns (bytes32) {
        return _hashTypedDataV4(_hashReport(report));
    }

    function _hashReport(
        CrossChainTypes.StrategyReport calldata report
    ) internal pure returns (bytes32) {
        bytes32 digest;
        bytes32 reportTypeHash = REPORT_TYPEHASH;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, reportTypeHash)
            mstore(add(ptr, 0x20), calldataload(report))
            mstore(add(ptr, 0x40), calldataload(add(report, 0x20)))
            mstore(add(ptr, 0x60), calldataload(add(report, 0x40)))
            mstore(add(ptr, 0x80), calldataload(add(report, 0x60)))
            mstore(add(ptr, 0xa0), calldataload(add(report, 0x80)))
            mstore(add(ptr, 0xc0), calldataload(add(report, 0xa0)))
            mstore(add(ptr, 0xe0), calldataload(add(report, 0xc0)))
            mstore(add(ptr, 0x100), calldataload(add(report, 0xe0)))
            digest := keccak256(ptr, 0x120)
        }
        return digest;
    }

    function _acceptReport(CrossChainTypes.StrategyReport calldata report) internal {
        if (!STRATEGY_REGISTRY.strategyExists(report.strategyId)) {
            revert ReportSettler__UnknownStrategy();
        }

        CrossChainTypes.StrategyConfig memory config = STRATEGY_REGISTRY
            .getStrategyConfig(report.strategyId);
        CrossChainTypes.StrategyReport memory previous = _reports[report.strategyId];

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

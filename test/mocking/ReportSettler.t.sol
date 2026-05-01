// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract ReportSettlerTests is Test {
    uint32 internal constant STRATEGY_ID = 1;
    uint32 internal constant REMOTE_CHAIN_ID = 30_101;

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    ReportSettler internal settler;

    address internal reporter = makeAddr("reporter");
    address internal remoteAgent = makeAddr("remoteAgent");
    uint256 internal attestorKey = 0xA11CE;
    address internal attestor;
    uint256 internal rogueKey = 0xBADC0DE;

    function setUp() public {
        asset = new MockERC20("USD Coin", "USDC", 6);
        registry = new StrategyRegistry(address(this));
        settler = new ReportSettler(address(this), registry);

        attestor = vm.addr(attestorKey);

        settler.grantRole(settler.REPORTER_ROLE(), reporter);
        settler.grantRole(settler.REPORT_ATTESTOR_ROLE(), attestor);

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: REMOTE_CHAIN_ID,
                agent: remoteAgent,
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 50,
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );
    }

    function testSubmitReportAcceptsFreshReport() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );

        vm.prank(reporter);
        settler.submitReport(report);

        CrossChainTypes.StrategyReport memory stored = settler.getLastReport(
            STRATEGY_ID
        );
        assertEq(stored.totalValue, report.totalValue);
        assertEq(stored.reportTimestamp, report.reportTimestamp);
    }

    function testSubmitReportRejectsStaleReport() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );

        vm.warp(block.timestamp + 2 days);

        vm.prank(reporter);
        vm.expectRevert(ReportSettler.ReportSettler__ReportStale.selector);
        settler.submitReport(report);
    }

    function testSubmitReportRejectsOutdatedReportTimestamp() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );

        vm.prank(reporter);
        settler.submitReport(report);

        CrossChainTypes.StrategyReport memory outdated = _buildReport(
            uint64(block.timestamp)
        );

        vm.prank(reporter);
        vm.expectRevert(ReportSettler.ReportSettler__ReportOutdated.selector);
        settler.submitReport(outdated);
    }

    function testSubmitReportRejectsChainMismatch() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );
        report.chainId = REMOTE_CHAIN_ID + 1;

        vm.prank(reporter);
        vm.expectRevert(ReportSettler.ReportSettler__ChainMismatch.selector);
        settler.submitReport(report);
    }

    function testSubmitReportAttestedAcceptsAuthorizedSignature() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );
        bytes memory signature = _signReport(report, attestorKey);

        settler.submitReportAttested(report, signature);

        CrossChainTypes.StrategyReport memory stored = settler.getLastReport(
            STRATEGY_ID
        );
        assertEq(stored.totalValue, report.totalValue);
        assertEq(stored.reportTimestamp, report.reportTimestamp);
    }

    function testSubmitReportAttestedRejectsUnauthorizedSigner() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );
        bytes memory signature = _signReport(report, rogueKey);

        vm.expectRevert(ReportSettler.ReportSettler__AttestorNotAuthorized.selector);
        settler.submitReportAttested(report, signature);
    }

    function testSubmitReportAttestedRejectsReplay() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );
        bytes memory signature = _signReport(report, attestorKey);

        settler.submitReportAttested(report, signature);

        vm.expectRevert(ReportSettler.ReportSettler__ReportOutdated.selector);
        settler.submitReportAttested(report, signature);
    }

    function testSubmitReportRejectsWhenAttestationRequired() public {
        CrossChainTypes.StrategyReport memory report = _buildReport(
            uint64(block.timestamp)
        );

        settler.setAttestationRequired(true);

        vm.prank(reporter);
        vm.expectRevert(ReportSettler.ReportSettler__AttestationRequired.selector);
        settler.submitReport(report);
    }

    function _buildReport(
        uint64 reportTimestamp
    ) internal pure returns (CrossChainTypes.StrategyReport memory report) {
        report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: REMOTE_CHAIN_ID,
            totalValue: 120e6,
            freeLiquidity: 80e6,
            totalDebt: 110e6,
            pnl: int256(10e6),
            reportTimestamp: reportTimestamp,
            positionsHash: keccak256("positions")
        });
    }

    function _signReport(
        CrossChainTypes.StrategyReport memory report,
        uint256 signerKey
    ) internal view returns (bytes memory signature) {
        bytes32 digest = settler.reportDigest(report);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}

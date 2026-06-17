// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract ReportAttestationTests is Test {
    uint32 internal constant STRATEGY_ID = 1;
    uint32 internal constant CHAIN_ID = 1;

    StrategyRegistry internal registry;
    ReportSettler internal settler;

    uint256 internal attestorKey;
    address internal attestor;

    function setUp() public {
        registry = new StrategyRegistry(address(this));
        settler = new ReportSettler(address(this), registry);

        // Create one valid strategy config in the registry.
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: CHAIN_ID,
                agent: makeAddr("agent"),
                asset: address(new MockERC20("USD Coin", "USDC", 6)),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 100,
                maxReportDelay: 0,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );

        attestorKey = 0xA11CE;
        attestor = vm.addr(attestorKey);
        settler.grantRole(settler.REPORT_ATTESTOR_ROLE(), attestor);
    }

    function testSubmitReportAttestedAcceptsValidSignature() public {
        CrossChainTypes.StrategyReport memory report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: CHAIN_ID,
            totalValue: 1e6,
            freeLiquidity: 5e5,
            totalDebt: 5e5,
            pnl: 0,
            reportTimestamp: uint64(block.timestamp),
            positionsHash: keccak256("positions")
        });

        bytes32 digest = _reportDigest(report);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(makeAddr("anyone"));
        settler.submitReportAttested(report, sig);

        CrossChainTypes.StrategyReport memory last = settler.getLastReport(STRATEGY_ID);
        assertEq(last.reportTimestamp, report.reportTimestamp);
        assertEq(last.totalValue, report.totalValue);
        assertEq(last.freeLiquidity, report.freeLiquidity);
        assertEq(last.totalDebt, report.totalDebt);
        assertEq(last.positionsHash, report.positionsHash);
    }

    function testSubmitReportAttestedRevertsWhenSignerNotAuthorized() public {
        uint256 otherKey = 0xB0B;
        address other = vm.addr(otherKey);
        assertFalse(settler.hasRole(settler.REPORT_ATTESTOR_ROLE(), other));

        CrossChainTypes.StrategyReport memory report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: CHAIN_ID,
            totalValue: 1,
            freeLiquidity: 1,
            totalDebt: 1,
            pnl: 0,
            reportTimestamp: uint64(block.timestamp),
            positionsHash: keccak256("positions")
        });

        bytes32 digest = _reportDigest(report);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(ReportSettler.ReportSettler__AttestorNotAuthorized.selector);
        settler.submitReportAttested(report, sig);
    }

    function testSubmitReportAttestedRevertsOnInvalidSignature() public {
        CrossChainTypes.StrategyReport memory report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: CHAIN_ID,
            totalValue: 1,
            freeLiquidity: 1,
            totalDebt: 1,
            pnl: 0,
            reportTimestamp: uint64(block.timestamp),
            positionsHash: keccak256("positions")
        });

        bytes memory sig = hex"deadbeef";
        vm.expectRevert();
        settler.submitReportAttested(report, sig);
    }

    function _reportDigest(
        CrossChainTypes.StrategyReport memory report
    ) internal view returns (bytes32) {
        bytes32 typeHash = keccak256(
            "StrategyReport(uint32 strategyId,uint32 chainId,uint256 totalValue,uint256 freeLiquidity,uint256 totalDebt,int256 pnl,uint64 reportTimestamp,bytes32 positionsHash)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                report.strategyId,
                report.chainId,
                report.totalValue,
                report.freeLiquidity,
                report.totalDebt,
                report.pnl,
                report.reportTimestamp,
                report.positionsHash
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("CrossChainVaultReport")),
                keccak256(bytes("1")),
                block.chainid,
                address(settler)
            )
        );

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


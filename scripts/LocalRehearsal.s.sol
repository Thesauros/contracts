// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../contracts/crosschain/WithdrawalQueue.sol";
import {CrossChainTypes} from "../contracts/libraries/CrossChainTypes.sol";

contract LocalRehearsal is Script {
    uint32 internal constant STRATEGY_ID = 1;

    MockERC20 internal asset;
    StrategyRegistry internal registry;
    StrategyAllocator internal allocator;
    WithdrawalQueue internal queue;
    ReportSettler internal settler;
    CrossChainVault internal vault;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // For local rehearsal we keep roles on the deployer to reduce ceremony.
        address keeper = deployer;
        address allocatorRole = deployer;
        address bridge = deployer;

        // Dedicated attestor (not necessarily the deployer).
        uint256 attestorKey = vm.envOr("ATTESTOR_KEY", uint256(0xA11CE));
        address attestor = vm.addr(attestorKey);

        // One funded user for deposits/withdrawals.
        address alice = vm.envOr("ALICE", address(0));
        if (alice == address(0)) {
            alice = makeAddr("alice");
        }

        uint256 depositAmount = vm.envOr("DEPOSIT_ASSETS", uint256(1_000e6));
        uint256 allocateAmount = vm.envOr("ALLOCATE_ASSETS", uint256(250e6));
        uint256 recallAmount = vm.envOr("RECALL_ASSETS", uint256(100e6));

        vm.startBroadcast(deployerKey);

        asset = new MockERC20("USD Coin", "USDC", 6);
        registry = new StrategyRegistry(deployer);
        allocator = new StrategyAllocator(deployer, registry);
        queue = new WithdrawalQueue(deployer);
        settler = new ReportSettler(deployer, registry);

        vault = new CrossChainVault(
            asset,
            "CrossChain Vault",
            "ccUSDC",
            deployer,
            registry,
            allocator,
            settler,
            queue
        );

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), allocatorRole);
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), bridge);

        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), bridge);

        settler.grantRole(settler.REPORT_ATTESTOR_ROLE(), attestor);

        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: STRATEGY_ID,
                chainId: uint32(block.chainid),
                agent: makeAddr("remoteAgent"),
                asset: address(asset),
                debtLimit: uint96(type(uint96).max),
                maxSlippageBps: 100,
                maxReportDelay: 1 days,
                depositsEnabled: true,
                withdrawalsEnabled: true,
                emergencyExitOnly: false,
                kind: CrossChainTypes.StrategyKind.Custom
            })
        );

        // Fund Alice and deposit.
        asset.mint(alice, depositAmount);
        vm.stopBroadcast();

        vm.startBroadcast(deployerKey);
        vm.prank(alice);
        asset.approve(address(vault), depositAmount);

        vm.prank(alice);
        vault.deposit(depositAmount, alice);

        console2.log("vault", address(vault));
        console2.log("asset", address(asset));
        console2.log("homeIdle after deposit", vault.homeIdle());

        // Allocate: Created -> Sent -> Settled (accounting synced on the vault).
        bytes32 allocateOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Allocate,
            allocateAmount,
            0,
            uint64(block.timestamp + 1 days)
        );

        vault.syncOperationAccounting(allocateOpId); // Undefined -> Created
        allocator.setOperationStatus(allocateOpId, CrossChainTypes.OperationStatus.Sent);
        vault.syncOperationAccounting(allocateOpId); // Created -> Sent

        // Simulate that capital left the home chain by burning from the vault balance.
        // This is only for local rehearsal using MockERC20.
        asset.burn(address(vault), allocateAmount);

        allocator.setOperationStatus(allocateOpId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(allocateOpId); // Sent -> Settled

        console2.log("homeIdle after allocate", vault.homeIdle());

        // Submit an attested report and settle it on the vault.
        CrossChainTypes.StrategyReport memory report = CrossChainTypes.StrategyReport({
            strategyId: STRATEGY_ID,
            chainId: uint32(block.chainid),
            totalValue: allocateAmount,
            freeLiquidity: allocateAmount / 2,
            totalDebt: allocateAmount,
            pnl: 0,
            reportTimestamp: uint64(block.timestamp),
            positionsHash: keccak256("positions")
        });

        bytes32 digest = _reportDigest(address(settler), report);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attestorKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        settler.submitReportAttested(report, sig);
        vault.settleStrategyReport(STRATEGY_ID);

        console2.log("totalAssets after report", vault.totalAssets());

        // Recall: Created -> Executed -> Settled (plus simulated funds arrival).
        bytes32 recallOpId = allocator.createOperation(
            STRATEGY_ID,
            CrossChainTypes.OperationType.Recall,
            recallAmount,
            0,
            uint64(block.timestamp + 1 days)
        );

        vault.syncOperationAccounting(recallOpId); // Undefined -> Created
        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Executed);
        vault.syncOperationAccounting(recallOpId); // Created -> Executed

        // Simulate recall funds arriving home.
        asset.mint(address(vault), recallAmount);
        vault.receiveRecallFunds(recallAmount);

        allocator.setOperationStatus(recallOpId, CrossChainTypes.OperationStatus.Settled);
        vault.syncOperationAccounting(recallOpId); // Executed -> Settled

        console2.log("homeIdle after recall settlement", vault.homeIdle());
        console2.log("totalAssets after recall settlement", vault.totalAssets());

        vm.stopBroadcast();
    }

    function _reportDigest(
        address verifyingContract,
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
                verifyingContract
            )
        );

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}


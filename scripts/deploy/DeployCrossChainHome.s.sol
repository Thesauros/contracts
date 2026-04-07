// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract DeployCrossChainHome is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address governance = vm.envOr("GOVERNANCE", deployer);
        address keeper = vm.envOr("KEEPER", deployer);
        address allocatorRole = vm.envOr("ALLOCATOR", deployer);
        address reportAttestor = vm.envOr("REPORT_ATTESTOR", deployer);

        bool deployMockAsset = vm.envOr("DEPLOY_MOCK_ASSET", false);
        address assetAddr = vm.envOr("ASSET", address(0));
        uint8 assetDecimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(6)));

        string memory name = vm.envOr(
            "VAULT_NAME",
            string("CrossChain Vault (Home)")
        );
        string memory symbol = vm.envOr("VAULT_SYMBOL", string("ccHOME"));

        // Optional strategy bootstrap (can be done later after remote deploy).
        bool upsertStrategy = vm.envOr("UPSERT_STRATEGY", false);
        uint32 strategyId = uint32(vm.envOr("STRATEGY_ID", uint256(1)));
        uint32 remoteChainId = uint32(vm.envOr("REMOTE_CHAIN_ID", uint256(0)));
        address remoteAgent = vm.envOr("REMOTE_AGENT", address(0));

        vm.startBroadcast(deployerKey);

        IERC20 asset;
        if (deployMockAsset) {
            asset = IERC20(
                address(new MockERC20("Mock USDC", "mUSDC", assetDecimals))
            );
        } else {
            require(assetAddr != address(0), "ASSET required");
            asset = IERC20(assetAddr);
        }

        StrategyRegistry registry = new StrategyRegistry(governance);
        StrategyAllocator allocator = new StrategyAllocator(governance, registry);
        WithdrawalQueue queue = new WithdrawalQueue(governance);
        ReportSettler settler = new ReportSettler(governance, registry);
        StargateBridgeAdapter bridge = new StargateBridgeAdapter(governance);

        CrossChainVault vault = new CrossChainVault(
            asset,
            name,
            symbol,
            governance,
            registry,
            allocator,
            settler,
            queue
        );

        // Wire internal roles.
        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));

        // Wire operator roles.
        allocator.grantRole(allocator.ALLOCATOR_ROLE(), allocatorRole);
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), address(bridge));

        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), address(bridge));

        settler.grantRole(settler.REPORT_ATTESTOR_ROLE(), reportAttestor);

        // Route policy gating to the vault itself (implements ICrossChainRoutingPolicy).
        allocator.setRoutingPolicy(vault);

        if (upsertStrategy) {
            require(remoteChainId != 0, "REMOTE_CHAIN_ID required");
            require(remoteAgent != address(0), "REMOTE_AGENT required");

            registry.upsertStrategy(
                CrossChainTypes.StrategyConfig({
                    strategyId: strategyId,
                    chainId: remoteChainId,
                    agent: remoteAgent,
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
        }

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("governance", governance);
        console2.log("keeper", keeper);
        console2.log("allocator", allocatorRole);
        console2.log("reportAttestor", reportAttestor);
        console2.log("asset", address(asset));

        console2.log("registry", address(registry));
        console2.log("allocatorContract", address(allocator));
        console2.log("settler", address(settler));
        console2.log("queue", address(queue));
        console2.log("vault", address(vault));
        console2.log("bridge", address(bridge));
        console2.log("bridge.localPeer(bytes32)", bridge.localPeer());

        vm.stopBroadcast();
    }
}


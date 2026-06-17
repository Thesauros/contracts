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
import {CrossChainDeployConfig} from "./CrossChainDeployConfig.s.sol";

contract DeployCrossChainHome is CrossChainDeployConfig {
    struct Roles {
        address governance;
        address keeper;
        address allocator;
        address reportAttestor;
    }

    struct Bootstrap {
        bool upsertStrategy;
        uint32 strategyId;
        uint32 remoteChainId;
        address remoteAgent;
    }

    struct Core {
        IERC20 asset;
        StrategyRegistry registry;
        StrategyAllocator allocator;
        WithdrawalQueue queue;
        ReportSettler settler;
        StargateBridgeAdapter bridge;
        CrossChainVault vault;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        Roles memory roles = Roles({
            governance: vm.envOr("GOVERNANCE", deployer),
            keeper: vm.envOr("KEEPER", deployer),
            allocator: vm.envOr("ALLOCATOR", deployer),
            reportAttestor: vm.envOr("REPORT_ATTESTOR", deployer)
        });

        Bootstrap memory bootstrap = Bootstrap({
            upsertStrategy: vm.envOr("UPSERT_STRATEGY", false),
            strategyId: uint32(vm.envOr("STRATEGY_ID", uint256(1))),
            remoteChainId: uint32(vm.envOr("REMOTE_CHAIN_ID", uint256(0))),
            remoteAgent: vm.envOr("REMOTE_AGENT", address(0))
        });

        vm.startBroadcast(deployerKey);

        Core memory core = _deployCore(roles);
        _wireRoles(core, roles);
        core.allocator.setRoutingPolicy(core.vault);
        _maybeUpsertStrategy(core, bootstrap);
        _logDeployment(deployer, roles, core);

        vm.stopBroadcast();
    }

    function _deployCore(Roles memory roles) internal returns (Core memory core) {
        core.asset = _deployOrResolveAsset();
        core.registry = new StrategyRegistry(roles.governance);
        core.allocator = new StrategyAllocator(roles.governance, core.registry);
        core.queue = new WithdrawalQueue(roles.governance);
        core.settler = new ReportSettler(roles.governance, core.registry);
        core.bridge = new StargateBridgeAdapter(roles.governance);
        core.vault = new CrossChainVault(
            core.asset,
            vm.envOr("VAULT_NAME", string("CrossChain Vault (Home)")),
            vm.envOr("VAULT_SYMBOL", string("ccHOME")),
            roles.governance,
            core.registry,
            core.allocator,
            core.settler,
            core.queue
        );
    }

    function _deployOrResolveAsset() internal returns (IERC20) {
        if (vm.envOr("DEPLOY_MOCK_ASSET", false)) {
            uint8 decimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(6)));
            return IERC20(address(new MockERC20("Mock USDC", "mUSDC", decimals)));
        }

        return IERC20(_assetForCurrentChain());
    }

    function _wireRoles(Core memory core, Roles memory roles) internal {
        // Wire internal roles.
        core.registry.grantRole(core.registry.VAULT_ROLE(), address(core.vault));
        core.queue.grantRole(core.queue.VAULT_ROLE(), address(core.vault));

        // Wire operator roles.
        core.allocator.grantRole(core.allocator.ALLOCATOR_ROLE(), roles.allocator);
        core.allocator.grantRole(core.allocator.KEEPER_ROLE(), roles.keeper);
        core.allocator.grantRole(
            core.allocator.BRIDGE_ROLE(),
            address(core.bridge)
        );
        core.allocator.grantRole(
            core.allocator.BRIDGE_ROLE(),
            address(core.vault)
        );

        core.vault.grantRole(core.vault.KEEPER_ROLE(), roles.keeper);
        core.vault.grantRole(core.vault.BRIDGE_ROLE(), address(core.bridge));
        core.bridge.grantRole(core.bridge.BRIDGE_ROLE(), address(core.vault));

        core.settler.grantRole(
            core.settler.REPORT_ATTESTOR_ROLE(),
            roles.reportAttestor
        );
    }

    function _maybeUpsertStrategy(
        Core memory core,
        Bootstrap memory bootstrap
    ) internal {
        if (bootstrap.upsertStrategy) {
            require(bootstrap.remoteChainId != 0, "REMOTE_CHAIN_ID required");
            require(bootstrap.remoteAgent != address(0), "REMOTE_AGENT required");

            core.registry.upsertStrategy(
                CrossChainTypes.StrategyConfig({
                    strategyId: bootstrap.strategyId,
                    chainId: bootstrap.remoteChainId,
                    agent: bootstrap.remoteAgent,
                    asset: address(core.asset),
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
    }

    function _logDeployment(
        address deployer,
        Roles memory roles,
        Core memory core
    ) internal view {
        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("governance", roles.governance);
        console2.log("keeper", roles.keeper);
        console2.log("allocator", roles.allocator);
        console2.log("reportAttestor", roles.reportAttestor);
        console2.log("asset", address(core.asset));

        console2.log("registry", address(core.registry));
        console2.log("allocatorContract", address(core.allocator));
        console2.log("settler", address(core.settler));
        console2.log("queue", address(core.queue));
        console2.log("vault", address(core.vault));
        console2.log("bridge", address(core.bridge));
        console2.log("bridge.localPeer(bytes32)");
        console2.logBytes32(core.bridge.localPeer());
    }
}

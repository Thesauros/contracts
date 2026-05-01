// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {ReportSettler} from "../../contracts/crosschain/ReportSettler.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {WithdrawalQueue} from "../../contracts/crosschain/WithdrawalQueue.sol";
import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainDeployConfig} from "./CrossChainDeployConfig.s.sol";

contract ResumeCrossChainHome is CrossChainDeployConfig {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address governance = vm.envOr("GOVERNANCE", deployer);
        address keeper = vm.envOr("KEEPER", deployer);
        address allocatorRole = vm.envOr("ALLOCATOR", deployer);
        address reportAttestor = vm.envOr("REPORT_ATTESTOR", deployer);

        IERC20 asset = IERC20(_assetForCurrentChain());
        StrategyRegistry registry = StrategyRegistry(vm.envAddress("REGISTRY"));
        StrategyAllocator allocator = StrategyAllocator(
            vm.envAddress("ALLOCATOR_CONTRACT")
        );
        ReportSettler settler = ReportSettler(vm.envAddress("SETTLER"));
        WithdrawalQueue queue = WithdrawalQueue(vm.envAddress("QUEUE"));
        StargateBridgeAdapter bridge = StargateBridgeAdapter(
            vm.envAddress("BRIDGE_ADAPTER")
        );

        vm.startBroadcast(deployerKey);

        CrossChainVault vault = new CrossChainVault(
            asset,
            vm.envOr("VAULT_NAME", string("CrossChain Vault (Home)")),
            vm.envOr("VAULT_SYMBOL", string("ccHOME")),
            governance,
            registry,
            allocator,
            settler,
            queue
        );

        registry.grantRole(registry.VAULT_ROLE(), address(vault));
        queue.grantRole(queue.VAULT_ROLE(), address(vault));

        allocator.grantRole(allocator.ALLOCATOR_ROLE(), allocatorRole);
        allocator.grantRole(allocator.KEEPER_ROLE(), keeper);
        allocator.grantRole(allocator.BRIDGE_ROLE(), address(bridge));
        allocator.grantRole(allocator.BRIDGE_ROLE(), address(vault));

        vault.grantRole(vault.KEEPER_ROLE(), keeper);
        vault.grantRole(vault.BRIDGE_ROLE(), address(bridge));
        bridge.grantRole(bridge.BRIDGE_ROLE(), address(vault));

        settler.grantRole(settler.REPORT_ATTESTOR_ROLE(), reportAttestor);
        allocator.setRoutingPolicy(vault);

        vm.stopBroadcast();

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("asset", address(asset));
        console2.log("registry", address(registry));
        console2.log("allocatorContract", address(allocator));
        console2.log("settler", address(settler));
        console2.log("queue", address(queue));
        console2.log("bridge", address(bridge));
        console2.log("vault", address(vault));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract UpsertStrategy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address registryAddr = vm.envAddress("REGISTRY");
        uint32 strategyId = uint32(vm.envUint("STRATEGY_ID"));
        uint32 chainId = uint32(vm.envUint("CHAIN_ID"));
        address agent = vm.envAddress("AGENT");
        address asset = vm.envAddress("ASSET");
        uint96 debtLimit = uint96(vm.envOr("DEBT_LIMIT", uint256(0)));
        uint96 maxSlippageBps = uint96(vm.envOr("MAX_SLIPPAGE_BPS", uint256(100)));
        uint48 maxReportDelay = uint48(vm.envOr("MAX_REPORT_DELAY", uint256(1 days)));
        bool depositsEnabled = vm.envOr("DEPOSITS_ENABLED", true);
        bool withdrawalsEnabled = vm.envOr("WITHDRAWALS_ENABLED", true);
        bool emergencyExitOnly = vm.envOr("EMERGENCY_EXIT_ONLY", false);
        uint256 kind = vm.envOr("STRATEGY_KIND", uint256(4));

        vm.startBroadcast(deployerKey);

        StrategyRegistry registry = StrategyRegistry(registryAddr);
        registry.upsertStrategy(
            CrossChainTypes.StrategyConfig({
                strategyId: strategyId,
                chainId: chainId,
                agent: agent,
                asset: asset,
                debtLimit: debtLimit,
                maxSlippageBps: maxSlippageBps,
                maxReportDelay: maxReportDelay,
                depositsEnabled: depositsEnabled,
                withdrawalsEnabled: withdrawalsEnabled,
                emergencyExitOnly: emergencyExitOnly,
                kind: CrossChainTypes.StrategyKind(kind)
            })
        );

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("registry", registryAddr);
        console2.log("strategyId", strategyId);
        console2.log("strategyChainId", chainId);
        console2.log("agent", agent);
        console2.log("asset", asset);
        console2.log("debtLimit", debtLimit);
        console2.log("maxSlippageBps", maxSlippageBps);
        console2.log("maxReportDelay", maxReportDelay);
        console2.log("depositsEnabled", depositsEnabled);
        console2.log("withdrawalsEnabled", withdrawalsEnabled);
        console2.log("emergencyExitOnly", emergencyExitOnly);
        console2.log("kind", kind);

        vm.stopBroadcast();
    }
}

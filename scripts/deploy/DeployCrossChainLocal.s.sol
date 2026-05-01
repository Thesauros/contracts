// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LocalStrategyAgent} from "../../contracts/crosschain/LocalStrategyAgent.sol";
import {AaveV3StrategyAdapter} from "../../contracts/crosschain/AaveV3StrategyAdapter.sol";
import {MorphoStrategyAdapter} from "../../contracts/crosschain/MorphoStrategyAdapter.sol";
import {ERC4626StrategyAdapter} from "../../contracts/crosschain/ERC4626StrategyAdapter.sol";
import {IStrategyAdapter} from "../../contracts/interfaces/crosschain/IStrategyAdapter.sol";
import {CrossChainDeployConfig} from "./CrossChainDeployConfig.s.sol";

contract DeployCrossChainLocal is CrossChainDeployConfig {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address governance = vm.envOr("GOVERNANCE", deployer);
        address keeper = vm.envOr("KEEPER", deployer);
        address reporter = vm.envOr("REPORTER", governance);
        address guardian = vm.envOr("GUARDIAN", governance);

        address vault = vm.envAddress("VAULT");
        uint32 strategyId = uint32(vm.envOr("STRATEGY_ID", uint256(1)));

        address asset = _assetForCurrentChain();
        string memory adapterType = vm.envOr(
            "STRATEGY_ADAPTER",
            string("AAVE")
        );

        vm.startBroadcast(deployerKey);

        IStrategyAdapter adapter;
        if (_equals(adapterType, "AAVE")) {
            address provider = _aaveProviderForCurrentChain();
            adapter = new AaveV3StrategyAdapter(provider, asset);
        } else if (_equals(adapterType, "MORPHO")) {
            address metaMorpho = _metaMorphoForCurrentChain();
            adapter = new MorphoStrategyAdapter(metaMorpho);
        } else if (_equals(adapterType, "ERC4626")) {
            address erc4626Vault = vm.envAddress("ERC4626_VAULT");
            adapter = new ERC4626StrategyAdapter(erc4626Vault);
        } else {
            revert("Unknown STRATEGY_ADAPTER");
        }

        LocalStrategyAgent agent = new LocalStrategyAgent(
            governance,
            strategyId,
            vault
        );

        agent.grantRole(agent.KEEPER_ROLE(), keeper);
        agent.grantRole(agent.REPORTER_ROLE(), reporter);
        agent.grantRole(agent.GUARDIAN_ROLE(), guardian);

        agent.setAsset(asset);
        agent.setStrategyAdapter(address(adapter));

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("governance", governance);
        console2.log("keeper", keeper);
        console2.log("reporter", reporter);
        console2.log("guardian", guardian);
        console2.log("vault", vault);
        console2.log("strategyId", strategyId);
        console2.log("asset", asset);
        console2.log("adapter", address(adapter));
        console2.log("localAgent", address(agent));

        vm.stopBroadcast();
    }

    function _equals(
        string memory a,
        string memory b
    ) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

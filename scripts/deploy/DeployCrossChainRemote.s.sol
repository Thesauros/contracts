// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockERC4626Vault} from "../../contracts/mocks/MockERC4626Vault.sol";
import {ERC4626StrategyAdapter} from "../../contracts/crosschain/ERC4626StrategyAdapter.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {StargateBridgeAdapter} from "../../contracts/crosschain/StargateBridgeAdapter.sol";

contract DeployCrossChainRemote is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address governance = vm.envOr("GOVERNANCE", deployer);
        address keeper = vm.envOr("KEEPER", deployer);

        uint32 strategyId = uint32(vm.envOr("STRATEGY_ID", uint256(1)));

        bool deployMockAsset = vm.envOr("DEPLOY_MOCK_ASSET", false);
        address assetAddr = vm.envOr("ASSET", address(0));
        uint8 assetDecimals = uint8(vm.envOr("ASSET_DECIMALS", uint256(6)));

        // Optional: deploy a mock ERC4626 vault + adapter for rehearsal.
        bool deployMockErc4626 = vm.envOr("DEPLOY_MOCK_ERC4626", true);
        address erc4626VaultAddr = vm.envOr("ERC4626_VAULT", address(0));

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

        address erc4626Vault;
        if (deployMockErc4626) {
            erc4626Vault = address(
                new MockERC4626Vault(asset, "Mock 4626 Vault", "m4626")
            );
        } else {
            require(erc4626VaultAddr != address(0), "ERC4626_VAULT required");
            erc4626Vault = erc4626VaultAddr;
        }

        ERC4626StrategyAdapter adapter = new ERC4626StrategyAdapter(erc4626Vault);
        RemoteStrategyAgent agent = new RemoteStrategyAgent(governance, strategyId);
        StargateBridgeAdapter bridge = new StargateBridgeAdapter(governance);

        agent.grantRole(agent.KEEPER_ROLE(), keeper);
        agent.grantRole(agent.BRIDGE_ROLE(), address(bridge));

        // The remote agent calls sendAssetAndMessage on the bridge adapter when bridging funds home.
        bridge.grantRole(bridge.BRIDGE_ROLE(), address(agent));

        agent.setAsset(address(asset));
        agent.setStrategyAdapter(address(adapter));

        console2.log("chainId", block.chainid);
        console2.log("deployer", deployer);
        console2.log("governance", governance);
        console2.log("keeper", keeper);
        console2.log("strategyId", strategyId);
        console2.log("asset", address(asset));
        console2.log("erc4626Vault", erc4626Vault);
        console2.log("strategyAdapter", address(adapter));
        console2.log("remoteAgent", address(agent));
        console2.log("bridge", address(bridge));
        console2.log("bridge.localPeer(bytes32)", bridge.localPeer());

        vm.stopBroadcast();
    }
}


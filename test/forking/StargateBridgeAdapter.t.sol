// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";

import {
    StargateBridgeAdapter,
    IStargate
} from "../../contracts/crosschain/StargateBridgeAdapter.sol";
import {CrossChainVault} from "../../contracts/crosschain/CrossChainVault.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {StrategyAllocator} from "../../contracts/crosschain/StrategyAllocator.sol";
import {StrategyRegistry} from "../../contracts/crosschain/StrategyRegistry.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";

contract StargateBridgeAdapterForkTests is Test {
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant ARBITRUM_CHAIN_ID = 42161;

    address internal constant GOVERNANCE =
        0xafA9ed53c33bbD8DE300481ce150dB3D35738F9D;

    address internal constant BASE_USDC =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant ARBITRUM_USDC =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    uint32 internal constant BASE_EID = 30184;
    uint32 internal constant ARBITRUM_EID = 30110;
    uint32 internal constant STRATEGY_ID = 1;

    address internal constant BASE_REGISTRY =
        0xCaFaF5f72235B1F10C92d57Db512C802ec1D9ad2;
    address internal constant BASE_ALLOCATOR =
        0x0dB5b3401f526E3dFE46dFCA2297745AA16D2884;
    address internal constant BASE_BRIDGE =
        0xea7B7d019eEA0864723bD8c9e1c72eb81aa23C41;
    address internal constant BASE_VAULT =
        0x206Ac58E24888e852cB3F9f4540031a0D53298c2;

    address internal constant ARBITRUM_STRATEGY_ADAPTER =
        0xfAc846b296DA830A041217F32387763d31cE6998;
    address internal constant ARBITRUM_REMOTE_AGENT =
        0xf04D182F9990040A395E65D0151A30dB6957a9Ed;
    address internal constant ARBITRUM_BRIDGE =
        0xf91980fCA99B4094258966B81FB71b211DCFa529;

    bytes32 internal constant BASE_LOCAL_PEER =
        0x000000000000000000000000ea7b7d019eea0864723bd8c9e1c72eb81aa23c41;
    bytes32 internal constant BASE_REMOTE_PEER =
        0x000000000000000000000000f91980fca99b4094258966b81fb71b211dcfa529;
    bytes32 internal constant ARBITRUM_LOCAL_PEER =
        0x000000000000000000000000f91980fca99b4094258966b81fb71b211dcfa529;
    bytes32 internal constant ARBITRUM_REMOTE_PEER =
        0x000000000000000000000000ea7b7d019eea0864723bd8c9e1c72eb81aa23c41;

    function testBaseDeploymentSnapshotMatchesFork() public {
        _createForkOrSkip("BASE_RPC_URL");

        StargateBridgeAdapter bridge = StargateBridgeAdapter(BASE_BRIDGE);
        StrategyRegistry registry = StrategyRegistry(BASE_REGISTRY);
        StrategyAllocator allocator = StrategyAllocator(BASE_ALLOCATOR);
        CrossChainVault vault = CrossChainVault(BASE_VAULT);

        assertEq(block.chainid, BASE_CHAIN_ID);
        assertEq(uint256(bridge.localPeer()), uint256(BASE_LOCAL_PEER));
        assertEq(
            uint256(bridge.localPeer()),
            uint256(_peerForAddress(address(bridge)))
        );
        assertEq(
            uint256(bridge.peers(ARBITRUM_EID)),
            uint256(BASE_REMOTE_PEER)
        );
        assertTrue(bridge.hasRole(GOVERNANCE_ROLE, GOVERNANCE));

        assertEq(vault.entryChainId(), BASE_CHAIN_ID);
        assertEq(vault.asset(), BASE_USDC);
        assertEq(address(vault.strategyRegistry()), address(registry));
        assertEq(address(vault.strategyAllocator()), address(allocator));
        assertEq(address(allocator.strategyRegistry()), address(registry));
        assertEq(address(allocator.routingPolicy()), address(vault));

        assertTrue(vault.hasRole(BRIDGE_ROLE, address(bridge)));
        assertTrue(allocator.hasRole(BRIDGE_ROLE, address(bridge)));

        CrossChainTypes.StrategyConfig memory config = registry.getStrategyConfig(
            STRATEGY_ID
        );
        assertEq(config.strategyId, STRATEGY_ID);
        assertEq(config.chainId, ARBITRUM_EID);
        assertEq(config.agent, ARBITRUM_REMOTE_AGENT);
        assertEq(config.asset, ARBITRUM_USDC);
        assertEq(uint256(config.kind), uint256(CrossChainTypes.StrategyKind.Aave));
        assertTrue(config.depositsEnabled);
        assertTrue(config.withdrawalsEnabled);
        assertFalse(config.emergencyExitOnly);

        _assertLegacyOrConfiguredTransport(bridge, BASE_USDC);
    }

    function testArbitrumDeploymentSnapshotMatchesFork() public {
        _createForkOrSkip("ARBITRUM_RPC_URL");

        StargateBridgeAdapter bridge = StargateBridgeAdapter(ARBITRUM_BRIDGE);
        RemoteStrategyAgent remoteAgent = RemoteStrategyAgent(
            ARBITRUM_REMOTE_AGENT
        );

        assertEq(block.chainid, ARBITRUM_CHAIN_ID);
        assertEq(uint256(bridge.localPeer()), uint256(ARBITRUM_LOCAL_PEER));
        assertEq(
            uint256(bridge.localPeer()),
            uint256(_peerForAddress(address(bridge)))
        );
        assertEq(
            uint256(bridge.peers(BASE_EID)),
            uint256(ARBITRUM_REMOTE_PEER)
        );
        assertTrue(bridge.hasRole(GOVERNANCE_ROLE, GOVERNANCE));
        assertTrue(bridge.hasRole(BRIDGE_ROLE, address(remoteAgent)));

        assertEq(remoteAgent.strategyId(), STRATEGY_ID);
        assertEq(remoteAgent.asset(), ARBITRUM_USDC);
        assertEq(remoteAgent.strategyAdapter(), ARBITRUM_STRATEGY_ADAPTER);
        assertTrue(remoteAgent.hasRole(GOVERNANCE_ROLE, GOVERNANCE));
        assertTrue(remoteAgent.hasRole(BRIDGE_ROLE, address(bridge)));

        _assertLegacyOrConfiguredTransport(bridge, ARBITRUM_USDC);
    }

    function _assertLegacyOrConfiguredTransport(
        StargateBridgeAdapter bridge,
        address expectedAsset
    ) internal view {
        (bool hasStargateGetter, bytes memory stargateData) = address(bridge)
            .staticcall(abi.encodeWithSignature("stargate()"));
        if (!hasStargateGetter || stargateData.length < 32) {
            return;
        }

        address stargate = abi.decode(stargateData, (address));
        (bool hasEndpointGetter, bytes memory endpointData) = address(bridge)
            .staticcall(abi.encodeWithSignature("endpointV2()"));
        if (stargate == address(0)) {
            if (hasEndpointGetter && endpointData.length >= 32) {
                assertEq(abi.decode(endpointData, (address)), address(0));
            }
            return;
        }

        assertTrue(hasEndpointGetter && endpointData.length >= 32);
        assertTrue(abi.decode(endpointData, (address)) != address(0));
        assertEq(IStargate(stargate).token(), expectedAsset);
    }

    function _createForkOrSkip(string memory envKey) internal {
        string memory rpcUrl = vm.envOr(envKey, string(""));
        if (bytes(rpcUrl).length == 0) {
            vm.skip(true, string.concat(envKey, " is not set"));
            return;
        }

        vm.createSelectFork(rpcUrl);
    }

    function _peerForAddress(address account) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(account)));
    }
}

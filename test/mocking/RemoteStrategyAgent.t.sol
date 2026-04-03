// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {RemoteStrategyAgent} from "../../contracts/crosschain/RemoteStrategyAgent.sol";
import {CrossChainTypes} from "../../contracts/libraries/CrossChainTypes.sol";
import {MockERC20} from "../../contracts/mocks/MockERC20.sol";
import {MockStrategyAdapter} from "../../contracts/mocks/MockStrategyAdapter.sol";

contract RemoteStrategyAgentTests is Test {
    RemoteStrategyAgent internal agent;
    MockERC20 internal asset;
    MockStrategyAdapter internal strategyAdapter;

    address internal bridge = makeAddr("bridge");
    address internal keeper = makeAddr("keeper");
    address internal guardian = makeAddr("guardian");

    uint32 internal constant STRATEGY_ID = 7;
    uint32 internal constant SOURCE_CHAIN_ID = 8_453;

    function setUp() public {
        agent = new RemoteStrategyAgent(address(this), STRATEGY_ID);
        asset = new MockERC20("USD Coin", "USDC", 6);
        strategyAdapter = new MockStrategyAdapter(address(asset));

        agent.grantRole(agent.BRIDGE_ROLE(), bridge);
        agent.grantRole(agent.KEEPER_ROLE(), keeper);
        agent.grantRole(agent.GUARDIAN_ROLE(), guardian);
        agent.setAsset(address(asset));
        agent.setStrategyAdapter(address(strategyAdapter));
    }

    function testReceiveBridgeAssetTracksAllocateCommandAndIdleLiquidity() public {
        bytes32 opId = keccak256("allocate");
        bytes memory payload = _buildCommandPayload(
            opId,
            CrossChainTypes.CommandType.Allocate,
            100e6,
            0,
            bytes("allocate")
        );

        asset.mint(address(agent), 100e6);

        vm.prank(bridge);
        agent.receiveBridgeAsset(payload);

        RemoteStrategyAgent.StoredCommand memory commandState = agent
            .getCommandState(opId);

        assertEq(uint256(commandState.commandType), uint256(CrossChainTypes.CommandType.Allocate));
        assertEq(commandState.assets, 100e6);
        assertEq(commandState.minAssetsOut, 0);
        assertEq(commandState.receivedAt, block.timestamp);
        assertEq(commandState.executedAt, 0);
        assertEq(agent.idleAssets(), 100e6);
        assertEq(agent.deployedAssets(), 0);
    }

    function testExecuteAllocateDeploysCapitalViaStrategyAdapter() public {
        bytes32 opId = keccak256("allocate");
        bytes memory payload = _buildCommandPayload(
            opId,
            CrossChainTypes.CommandType.Allocate,
            80e6,
            0,
            bytes("allocate")
        );

        asset.mint(address(agent), 80e6);

        vm.prank(bridge);
        agent.receiveBridgeAsset(payload);

        vm.prank(keeper);
        agent.executeAllocate(payload);

        RemoteStrategyAgent.StoredCommand memory commandState = agent
            .getCommandState(opId);

        assertEq(commandState.executedAt, block.timestamp);
        assertEq(agent.idleAssets(), 0);
        assertEq(agent.deployedAssets(), 80e6);
        assertEq(strategyAdapter.deployedBalance(), 80e6);
        assertEq(asset.balanceOf(address(agent)), 0);
        assertEq(asset.balanceOf(address(strategyAdapter)), 80e6);
    }

    function testExecuteRecallFreesCapitalBackIntoIdleLiquidity() public {
        bytes32 allocateOpId = keccak256("allocate");
        bytes memory allocatePayload = _buildCommandPayload(
            allocateOpId,
            CrossChainTypes.CommandType.Allocate,
            120e6,
            0,
            bytes("allocate")
        );

        asset.mint(address(agent), 120e6);

        vm.startPrank(bridge);
        agent.receiveBridgeAsset(allocatePayload);
        vm.stopPrank();

        vm.prank(keeper);
        agent.executeAllocate(allocatePayload);

        bytes32 recallOpId = keccak256("recall");
        bytes memory recallPayload = _buildCommandPayload(
            recallOpId,
            CrossChainTypes.CommandType.Recall,
            50e6,
            50e6,
            bytes("recall")
        );

        vm.prank(bridge);
        agent.receiveBridgeAsset(recallPayload);

        vm.prank(keeper);
        agent.executeRecall(recallPayload);

        RemoteStrategyAgent.StoredCommand memory commandState = agent
            .getCommandState(recallOpId);

        assertEq(commandState.executedAt, block.timestamp);
        assertEq(agent.idleAssets(), 50e6);
        assertEq(agent.deployedAssets(), 70e6);
        assertEq(strategyAdapter.deployedBalance(), 70e6);
        assertEq(asset.balanceOf(address(agent)), 50e6);
        assertEq(asset.balanceOf(address(strategyAdapter)), 70e6);
    }

    function testReceiveBridgeAssetRejectsWrongStrategyId() public {
        bytes memory payload = abi.encode(
            CrossChainTypes.CommandPayloadV1({
                version: 1,
                opId: keccak256("wrong-strategy"),
                strategyId: STRATEGY_ID + 1,
                sourceChainId: SOURCE_CHAIN_ID,
                commandType: CrossChainTypes.CommandType.Allocate,
                assets: 10e6,
                minAssetsOut: 0,
                deadline: uint64(block.timestamp + 1 days),
                commandTimestamp: uint64(block.timestamp),
                params: bytes("")
            })
        );

        vm.prank(bridge);
        vm.expectRevert(
            abi.encodeWithSelector(
                RemoteStrategyAgent.RemoteStrategyAgent__InvalidStrategyId.selector,
                STRATEGY_ID + 1
            )
        );
        agent.receiveBridgeAsset(payload);
    }

    function testExecuteAllocateRejectsReplay() public {
        bytes32 opId = keccak256("allocate");
        bytes memory payload = _buildCommandPayload(
            opId,
            CrossChainTypes.CommandType.Allocate,
            25e6,
            0,
            bytes("")
        );

        asset.mint(address(agent), 25e6);

        vm.prank(bridge);
        agent.receiveBridgeAsset(payload);

        vm.prank(keeper);
        agent.executeAllocate(payload);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                RemoteStrategyAgent.RemoteStrategyAgent__CommandAlreadyExecuted.selector,
                opId
            )
        );
        agent.executeAllocate(payload);
    }

    function _buildCommandPayload(
        bytes32 opId,
        CrossChainTypes.CommandType commandType,
        uint256 assets_,
        uint256 minAssetsOut,
        bytes memory params
    ) internal view returns (bytes memory) {
        return
            abi.encode(
                CrossChainTypes.CommandPayloadV1({
                    version: 1,
                    opId: opId,
                    strategyId: STRATEGY_ID,
                    sourceChainId: SOURCE_CHAIN_ID,
                    commandType: commandType,
                    assets: assets_,
                    minAssetsOut: minAssetsOut,
                    deadline: uint64(block.timestamp + 1 days),
                    commandTimestamp: uint64(block.timestamp),
                    params: params
                })
            );
    }
}

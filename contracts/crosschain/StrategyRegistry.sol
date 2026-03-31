// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IStrategyRegistry} from "../interfaces/crosschain/IStrategyRegistry.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract StrategyRegistry is CrossChainAccessControl, IStrategyRegistry {
    error StrategyRegistry__InvalidStrategyId();
    error StrategyRegistry__InvalidAgent();
    error StrategyRegistry__InvalidAsset();
    error StrategyRegistry__UnknownStrategy();
    error StrategyRegistry__ChainMismatch();

    mapping(uint32 strategyId => CrossChainTypes.StrategyConfig) private _configs;
    mapping(uint32 strategyId => CrossChainTypes.StrategyState) private _states;
    mapping(uint32 strategyId => bool) private _exists;

    constructor(address admin) CrossChainAccessControl(admin) {}

    function upsertStrategy(
        CrossChainTypes.StrategyConfig calldata config
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (config.strategyId == 0) {
            revert StrategyRegistry__InvalidStrategyId();
        }
        if (config.agent == address(0)) {
            revert StrategyRegistry__InvalidAgent();
        }
        if (config.asset == address(0)) {
            revert StrategyRegistry__InvalidAsset();
        }

        _configs[config.strategyId] = config;

        if (!_exists[config.strategyId]) {
            _exists[config.strategyId] = true;
            _states[config.strategyId].health = CrossChainTypes.StrategyHealth.Active;
        }

        emit StrategyConfigured(
            config.strategyId,
            config.chainId,
            config.agent,
            config.asset
        );
    }

    function setStrategyState(
        uint32 strategyId,
        CrossChainTypes.StrategyState calldata state
    ) external onlyRole(GOVERNANCE_ROLE) {
        if (!_exists[strategyId]) {
            revert StrategyRegistry__UnknownStrategy();
        }
        if (_configs[strategyId].chainId == 0) {
            revert StrategyRegistry__ChainMismatch();
        }

        _states[strategyId] = state;

        emit StrategyStateUpdated(
            strategyId,
            state.health,
            state.currentDebt,
            state.lastReportedValue
        );
    }

    function getStrategyConfig(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyConfig memory) {
        if (!_exists[strategyId]) {
            revert StrategyRegistry__UnknownStrategy();
        }
        return _configs[strategyId];
    }

    function getStrategyState(
        uint32 strategyId
    ) external view returns (CrossChainTypes.StrategyState memory) {
        if (!_exists[strategyId]) {
            revert StrategyRegistry__UnknownStrategy();
        }
        return _states[strategyId];
    }

    function strategyExists(uint32 strategyId) external view returns (bool) {
        return _exists[strategyId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Script} from "forge-std/Script.sol";

abstract contract CrossChainDeployConfig is Script {
    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant ARBITRUM_CHAIN_ID = 42161;

    function _assetForCurrentChain() internal view returns (address) {
        address asset = vm.envOr("ASSET", address(0));
        if (asset != address(0)) {
            return asset;
        }

        if (block.chainid == BASE_CHAIN_ID) {
            return vm.envAddress("USDC_Base");
        }
        if (block.chainid == ARBITRUM_CHAIN_ID) {
            return vm.envAddress("USDC_Arbitrum");
        }

        revert("ASSET required");
    }

    function _aaveProviderForCurrentChain() internal view returns (address) {
        address provider = vm.envOr("AAVE_POOL_ADDRESSES_PROVIDER", address(0));
        if (provider != address(0)) {
            return provider;
        }

        if (block.chainid == BASE_CHAIN_ID) {
            return vm.envAddress("AAVE_POOL_ADDRESSES_PROVIDER_BASE");
        }
        if (block.chainid == ARBITRUM_CHAIN_ID) {
            return vm.envAddress("AAVE_POOL_ADDRESSES_PROVIDER_ARBITRUM");
        }

        revert("AAVE_POOL_ADDRESSES_PROVIDER required");
    }

    function _metaMorphoForCurrentChain() internal view returns (address) {
        address metaMorpho = vm.envOr("META_MORPHO", address(0));
        if (metaMorpho != address(0)) {
            return metaMorpho;
        }

        if (block.chainid == BASE_CHAIN_ID) {
            return vm.envAddress("META_MORPHO_BASE");
        }

        revert("META_MORPHO required");
    }

    function _stargateEidForChain(
        uint256 chainId
    ) internal view returns (uint32) {
        if (chainId == BASE_CHAIN_ID) {
            return uint32(vm.envUint("EID_Stargate_BASE"));
        }
        if (chainId == ARBITRUM_CHAIN_ID) {
            return uint32(vm.envUint("EID_Stargate_Arbitrum"));
        }

        revert("Unsupported Stargate EID chain");
    }
}

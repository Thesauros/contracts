// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {LayerZeroBridgeAdapter} from "./LayerZeroBridgeAdapter.sol";

/// @dev Stargate is built on LayerZero messaging. For this repository we keep an adapter that
///      implements the `IBridgeAdapter` surface and is used by the control plane. The adapter is
///      intentionally "bridge-agnostic" and can be wired to Stargate execution in production.
contract StargateBridgeAdapter is LayerZeroBridgeAdapter {
    constructor(address admin) LayerZeroBridgeAdapter(admin) {}
}


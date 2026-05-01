// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {ICrossChainControlPlane} from "./ICrossChainControlPlane.sol";
import {ICrossChainEntryVault} from "./ICrossChainEntryVault.sol";

interface ICrossChainVault is ICrossChainEntryVault, ICrossChainControlPlane {}

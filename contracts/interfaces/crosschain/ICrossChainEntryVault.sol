// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IWithdrawalQueue} from "./IWithdrawalQueue.sol";
import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface ICrossChainEntryVault is IERC4626 {
    function entryChainId() external view returns (uint256);

    function withdrawalQueue() external view returns (IWithdrawalQueue);

    function instantWithdrawalCapacity() external view returns (uint256);

    function currentRedemptionMode()
        external
        view
        returns (CrossChainTypes.RedemptionMode);

    function currentRedemptionSla() external view returns (uint64);

    function positionView(
        address owner
    ) external view returns (CrossChainTypes.EntryPosition memory);

    function requestWithdrawal(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 requestId, uint256 assetsPreview);

    function claimWithdrawal(uint256 requestId) external returns (uint256 assets);

    function cancelWithdrawal(uint256 requestId) external;
}

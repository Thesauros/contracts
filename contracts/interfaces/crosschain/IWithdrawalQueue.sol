// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainTypes} from "../../libraries/CrossChainTypes.sol";

interface IWithdrawalQueue {
    event WithdrawalQueued(
        uint256 indexed requestId,
        address indexed owner,
        address indexed receiver,
        uint256 shares,
        uint256 assetsPreview
    );
    event WithdrawalStatusUpdated(
        uint256 indexed requestId,
        CrossChainTypes.WithdrawalStatus status
    );
    event WithdrawalTimestampsUpdated(
        uint256 indexed requestId,
        uint64 updatedAt,
        uint64 fundedAt,
        uint64 claimedAt
    );

    function getWithdrawalRequest(
        uint256 requestId
    ) external view returns (CrossChainTypes.WithdrawalRequest memory);

    function queueWithdrawal(
        address owner,
        address receiver,
        uint256 shares,
        uint256 assetsPreview
    ) external returns (uint256 requestId);

    function setWithdrawalStatus(
        uint256 requestId,
        CrossChainTypes.WithdrawalStatus status
    ) external;
}

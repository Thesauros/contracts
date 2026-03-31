// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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

    function getWithdrawalRequest(
        uint256 requestId
    ) external view returns (CrossChainTypes.WithdrawalRequest memory);
}

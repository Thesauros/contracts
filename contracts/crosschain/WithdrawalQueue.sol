// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IWithdrawalQueue} from "../interfaces/crosschain/IWithdrawalQueue.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract WithdrawalQueue is CrossChainAccessControl, IWithdrawalQueue {
    error WithdrawalQueue__UnknownRequest();

    uint256 public nextRequestId = 1;

    mapping(uint256 requestId => CrossChainTypes.WithdrawalRequest) private _requests;

    constructor(address admin) CrossChainAccessControl(admin) {}

    function queueWithdrawal(
        address owner,
        address receiver,
        uint256 shares,
        uint256 assetsPreview
    ) external onlyRole(KEEPER_ROLE) returns (uint256 requestId) {
        requestId = nextRequestId++;

        _requests[requestId] = CrossChainTypes.WithdrawalRequest({
            requestId: requestId,
            owner: owner,
            receiver: receiver,
            shares: shares,
            assetsPreview: assetsPreview,
            createdAt: uint64(block.timestamp),
            status: CrossChainTypes.WithdrawalStatus.Pending
        });

        emit WithdrawalQueued(
            requestId,
            owner,
            receiver,
            shares,
            assetsPreview
        );
    }

    function setWithdrawalStatus(
        uint256 requestId,
        CrossChainTypes.WithdrawalStatus status
    ) external onlyRole(KEEPER_ROLE) {
        if (_requests[requestId].requestId == 0) {
            revert WithdrawalQueue__UnknownRequest();
        }

        _requests[requestId].status = status;
        emit WithdrawalStatusUpdated(requestId, status);
    }

    function getWithdrawalRequest(
        uint256 requestId
    ) external view returns (CrossChainTypes.WithdrawalRequest memory) {
        if (_requests[requestId].requestId == 0) {
            revert WithdrawalQueue__UnknownRequest();
        }
        return _requests[requestId];
    }
}

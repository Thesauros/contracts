// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {CrossChainAccessControl} from "../access/CrossChainAccessControl.sol";
import {IWithdrawalQueue} from "../interfaces/crosschain/IWithdrawalQueue.sol";
import {CrossChainTypes} from "../libraries/CrossChainTypes.sol";

contract WithdrawalQueue is CrossChainAccessControl, IWithdrawalQueue {
    error WithdrawalQueue__UnknownRequest();
    error WithdrawalQueue__InvalidStatusTransition(
        CrossChainTypes.WithdrawalStatus currentStatus,
        CrossChainTypes.WithdrawalStatus nextStatus
    );

    uint256 public nextRequestId = 1;

    mapping(uint256 requestId => CrossChainTypes.WithdrawalRequest) private _requests;

    constructor(address admin) CrossChainAccessControl(admin) {}

    function queueWithdrawal(
        address owner,
        address receiver,
        uint256 shares,
        uint256 assetsPreview
    ) external returns (uint256 requestId) {
        if (
            !hasRole(KEEPER_ROLE, msg.sender) &&
            !hasRole(VAULT_ROLE, msg.sender)
        ) {
            revert AccessControlUnauthorizedAccount(msg.sender, VAULT_ROLE);
        }

        requestId = nextRequestId++;

        _requests[requestId] = CrossChainTypes.WithdrawalRequest({
            requestId: requestId,
            owner: owner,
            receiver: receiver,
            shares: shares,
            assetsPreview: assetsPreview,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            fundedAt: 0,
            claimedAt: 0,
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
    ) external {
        if (
            !hasRole(KEEPER_ROLE, msg.sender) &&
            !hasRole(VAULT_ROLE, msg.sender)
        ) {
            revert AccessControlUnauthorizedAccount(msg.sender, VAULT_ROLE);
        }

        if (_requests[requestId].requestId == 0) {
            revert WithdrawalQueue__UnknownRequest();
        }

        CrossChainTypes.WithdrawalRequest storage request = _requests[requestId];
        if (!_isValidStatusTransition(request.status, status)) {
            revert WithdrawalQueue__InvalidStatusTransition(
                request.status,
                status
            );
        }

        request.status = status;
        request.updatedAt = uint64(block.timestamp);

        if (status == CrossChainTypes.WithdrawalStatus.Funded) {
            request.fundedAt = uint64(block.timestamp);
        } else if (status == CrossChainTypes.WithdrawalStatus.Claimed) {
            request.claimedAt = uint64(block.timestamp);
        }

        emit WithdrawalStatusUpdated(requestId, status);
        emit WithdrawalTimestampsUpdated(
            requestId,
            request.updatedAt,
            request.fundedAt,
            request.claimedAt
        );
    }

    function getWithdrawalRequest(
        uint256 requestId
    ) external view returns (CrossChainTypes.WithdrawalRequest memory) {
        if (_requests[requestId].requestId == 0) {
            revert WithdrawalQueue__UnknownRequest();
        }
        return _requests[requestId];
    }

    function _isValidStatusTransition(
        CrossChainTypes.WithdrawalStatus currentStatus,
        CrossChainTypes.WithdrawalStatus nextStatus
    ) internal pure returns (bool) {
        if (currentStatus == nextStatus) {
            return false;
        }

        if (currentStatus == CrossChainTypes.WithdrawalStatus.Pending) {
            return
                nextStatus == CrossChainTypes.WithdrawalStatus.Processing ||
                nextStatus == CrossChainTypes.WithdrawalStatus.Funded ||
                nextStatus == CrossChainTypes.WithdrawalStatus.Cancelled;
        }

        if (currentStatus == CrossChainTypes.WithdrawalStatus.Processing) {
            return
                nextStatus == CrossChainTypes.WithdrawalStatus.Funded ||
                nextStatus == CrossChainTypes.WithdrawalStatus.Cancelled;
        }

        if (currentStatus == CrossChainTypes.WithdrawalStatus.Funded) {
            return nextStatus == CrossChainTypes.WithdrawalStatus.Claimed;
        }

        return false;
    }
}

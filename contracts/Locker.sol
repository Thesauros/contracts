// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Locker
 *
 * @notice Contract for locking ERC20 tokens, primarily designed for tokenized shares.
 */
contract Locker is Ownable2Step {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error Locker__InvalidTokenAmount();
    error Locker__TokenNotSupported();
    error Locker__AddressZero();

    struct LockInfo {
        address token;
        uint256 amount;
        uint256 lockedAt;
    }

    address[] internal _tokens;

    mapping(uint256 => LockInfo) public lockInfo; // lockId => lock info
    mapping(uint256 => address) private _beneficiaries; // lockId => beneficiary
    mapping(address => uint256) private _totalLocked; // token => total locked

    uint256 public nextLockId;

    event TokensLocked(
        uint256 lockId,
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event TokensChanged(address[] tokens);

    event TokensWithdrawn(
        IERC20 indexed token,
        address indexed to,
        uint256 amount
    );

    /**
     * @dev Initializes the Locker contract with the specified parameters.
     * @param owner_ The address of the initial owner of the contract.
     * @param tokens_ The array of the initial tokens that can be locked.
     */
    constructor(address owner_, address[] memory tokens_) Ownable(owner_) {
        _setTokens(tokens_);
    }

    /**
     * @notice Locks the specified amount of the given token.
     * @param token The address of the token to be locked.
     * @param amount The amount of tokens to be locked.
     */
    function lockTokens(address token, uint256 amount) external {
        if (amount == 0) {
            revert Locker__InvalidTokenAmount();
        }
        if (!_validateToken(token)) {
            revert Locker__TokenNotSupported();
        }

        LockInfo memory userLock = LockInfo({
            token: token,
            amount: amount,
            lockedAt: block.timestamp
        });

        uint256 newLockId = nextLockId;
        lockInfo[newLockId] = userLock;
        _beneficiaries[newLockId] = msg.sender;

        _totalLocked[token] += amount;

        nextLockId++;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit TokensLocked(newLockId, msg.sender, token, amount);
    }

    /**
     * @notice Updates the list of tokens that can be locked.
     * @param tokens The array of token addresses to be allowed.
     */
    function setTokens(address[] memory tokens) external onlyOwner {
        _setTokens(tokens);
    }

    /**
     * @notice Withdraws all of the specified token from the contract to a recipient.
     * @param to The address of the recipient.
     * @param token The token to be withdrawn.
     */
    function withdrawTokens(IERC20 token, address to) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(to, balance);

        emit TokensWithdrawn(token, to, balance);
    }

    /**
     * @dev Internal function to update the list of tokens that can be locked.
     * @param tokens The array of token addresses to be allowed.
     */
    function _setTokens(address[] memory tokens) internal {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                revert Locker__AddressZero();
            }
        }

        _tokens = tokens;
        emit TokensChanged(_tokens);
    }

    /**
     * @dev Returns true if the specified token is allowed to be locked.
     * @param token The address of the token to validate.
     */
    function _validateToken(address token) internal view returns (bool valid) {
        uint256 count = _tokens.length;
        for (uint256 i; i < count; i++) {
            if (token == _tokens[i]) {
                valid = true;
                break;
            }
        }
    }

    /**
     * @notice Returns the beneficiary of a specific lock.
     */
    function getBeneficiary(uint256 lockId) public view returns (address) {
        return _beneficiaries[lockId];
    }

    /**
     * @notice Returns the list of tokens that can be locked.
     */
    function getTokens() public view returns (address[] memory) {
        return _tokens;
    }

    /**
     * @notice Returns the total amount of the specified token that is currently locked.
     */
    function getTotalLocked(address token) public view returns (uint256) {
        return _totalLocked[token];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManager} from "./access/AccessManager.sol";
import {IVault} from "./interfaces/IVault.sol";

/**
 * @title WeeklyProfitFeeCollector
 * @dev Automatically collects 25% of user profits on a weekly basis
 */
contract WeeklyProfitFeeCollector is AccessManager {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error WeeklyProfitFeeCollector__InvalidVault();
    error WeeklyProfitFeeCollector__InvalidFeePercent();
    error WeeklyProfitFeeCollector__NotEnoughTimePassed();
    error WeeklyProfitFeeCollector__NoProfitsToCollect();
    error WeeklyProfitFeeCollector__TransferFailed();
    error WeeklyProfitFeeCollector__UserNotRegistered();

    /**
     * @dev Events
     */
    event VaultRegistered(address indexed vault, uint256 feePercent);
    event VaultUnregistered(address indexed vault);
    event UserRegistered(address indexed vault, address indexed user, uint256 initialShares);
    event ProfitFeeCollected(address indexed vault, address indexed user, uint256 profit, uint256 fee);
    event FeePercentUpdated(address indexed vault, uint256 newFeePercent);
    event TreasuryUpdated(address indexed newTreasury);

    /**
     * @dev Struct to store user profit tracking information
     */
    struct UserInfo {
        bool isRegistered;
        uint256 lastCollectionTime;
        uint256 lastShares; // Shares at last collection
        uint256 totalFeesCollected;
        uint256 totalProfitsCollected;
    }

    /**
     * @dev Struct to store vault collection information
     */
    struct VaultInfo {
        bool isRegistered;
        uint256 feePercent; // Fee percentage (25% = 2500 basis points)
        uint256 collectionInterval; // in seconds (7 days)
        uint256 totalFeesCollected;
    }

    /**
     * @dev State variables
     */
    address public treasury;
    mapping(address => VaultInfo) public vaults;
    mapping(address => mapping(address => UserInfo)) public userInfo; // vault => user => info
    address[] public registeredVaults;

    /**
     * @dev Constants
     */
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_FEE_PERCENT = 5000; // Maximum 50% fee
    uint256 public constant DEFAULT_COLLECTION_INTERVAL = 7 days; // 7 days
    uint256 public constant MIN_COLLECTION_INTERVAL = 1 days; // Minimum 1 day
    uint256 public constant MAX_COLLECTION_INTERVAL = 30 days; // Maximum 30 days

    /**
     * @dev Constructor
     * @param _treasury The treasury address to collect fees to
     */
    constructor(address _treasury) {
        if (_treasury == address(0)) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }
        treasury = _treasury;
    }

    /**
     * @notice Registers a vault for weekly profit fee collection
     * @param vault The vault address to register
     * @param feePercent The fee percentage in basis points (2500 = 25%)
     */
    function registerVault(address vault, uint256 feePercent) external onlyAdmin {
        if (vault == address(0)) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }
        if (feePercent > MAX_FEE_PERCENT) {
            revert WeeklyProfitFeeCollector__InvalidFeePercent();
        }

        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            registeredVaults.push(vault);
        }

        vaultInfo.isRegistered = true;
        vaultInfo.feePercent = feePercent;
        vaultInfo.collectionInterval = DEFAULT_COLLECTION_INTERVAL;

        emit VaultRegistered(vault, feePercent);
    }

    /**
     * @notice Unregisters a vault from profit fee collection
     * @param vault The vault address to unregister
     */
    function unregisterVault(address vault) external onlyAdmin {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }

        vaultInfo.isRegistered = false;

        // Remove from registeredVaults array
        for (uint256 i = 0; i < registeredVaults.length; i++) {
            if (registeredVaults[i] == vault) {
                registeredVaults[i] = registeredVaults[registeredVaults.length - 1];
                registeredVaults.pop();
                break;
            }
        }

        emit VaultUnregistered(vault);
    }

    /**
     * @notice Updates the fee percentage for a vault
     * @param vault The vault address
     * @param newFeePercent The new fee percentage in basis points
     */
    function updateFeePercent(address vault, uint256 newFeePercent) external onlyAdmin {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }
        if (newFeePercent > MAX_FEE_PERCENT) {
            revert WeeklyProfitFeeCollector__InvalidFeePercent();
        }

        vaultInfo.feePercent = newFeePercent;
        emit FeePercentUpdated(vault, newFeePercent);
    }

    /**
     * @notice Registers a user for profit tracking
     * @param vault The vault address
     * @param user The user address to register
     */
    function registerUser(address vault, address user) external {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }

        UserInfo storage userInfoStorage = userInfo[vault][user];
        if (userInfoStorage.isRegistered) {
            return; // Already registered
        }

        IVault vaultContract = IVault(vault);
        uint256 currentShares = vaultContract.balanceOf(user);

        userInfoStorage.isRegistered = true;
        userInfoStorage.lastCollectionTime = block.timestamp;
        userInfoStorage.lastShares = currentShares;

        emit UserRegistered(vault, user, currentShares);
    }

    /**
     * @notice Collects profit fees from a specific user
     * @param vault The vault address
     * @param user The user address to collect fees from
     */
    function collectUserProfitFees(address vault, address user) external {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }

        UserInfo storage userInfoStorage = userInfo[vault][user];
        if (!userInfoStorage.isRegistered) {
            revert WeeklyProfitFeeCollector__UserNotRegistered();
        }

        if (block.timestamp < userInfoStorage.lastCollectionTime + vaultInfo.collectionInterval) {
            revert WeeklyProfitFeeCollector__NotEnoughTimePassed();
        }

        IVault vaultContract = IVault(vault);
        uint256 currentShares = vaultContract.balanceOf(user);
        
        if (currentShares <= userInfoStorage.lastShares) {
            // No profit to collect
            userInfoStorage.lastCollectionTime = block.timestamp;
            userInfoStorage.lastShares = currentShares;
            return;
        }

        uint256 profitShares = currentShares - userInfoStorage.lastShares;
        uint256 profitAssets = vaultContract.convertToAssets(profitShares);
        uint256 fee = (profitAssets * vaultInfo.feePercent) / BASIS_POINTS;

        if (fee == 0) {
            // No fee to collect
            userInfoStorage.lastCollectionTime = block.timestamp;
            userInfoStorage.lastShares = currentShares;
            return;
        }

        // Calculate how many shares to burn to collect the fee
        uint256 feeShares = vaultContract.convertToShares(fee);
        
        // Transfer shares from user to this contract
        vaultContract.transferFrom(user, address(this), feeShares);
        
        // Redeem shares for assets
        uint256 assetsReceived = vaultContract.redeem(feeShares, address(this), address(this));
        
        // Transfer assets to treasury
        IERC20(vaultContract.asset()).safeTransfer(treasury, assetsReceived);

        // Update user info
        userInfoStorage.lastCollectionTime = block.timestamp;
        userInfoStorage.lastShares = currentShares - feeShares;
        userInfoStorage.totalFeesCollected += assetsReceived;
        userInfoStorage.totalProfitsCollected += profitAssets;

        // Update vault info
        vaultInfo.totalFeesCollected += assetsReceived;

        emit ProfitFeeCollected(vault, user, profitAssets, assetsReceived);
    }

    /**
     * @notice Collects profit fees from all registered users in a vault
     * @param vault The vault address
     */
    function collectAllUserProfitFees(address vault) external view {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }

        // This would require iterating through all users, which is gas-intensive
        // In practice, you might want to implement a different approach
        // For now, this is a placeholder that would need to be called per user
        revert WeeklyProfitFeeCollector__NoProfitsToCollect();
    }

    /**
     * @notice Sets the treasury address
     * @param _treasury The new treasury address
     */
    function setTreasury(address _treasury) external onlyAdmin {
        if (_treasury == address(0)) {
            revert WeeklyProfitFeeCollector__InvalidVault();
        }
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    /**
     * @notice Gets the number of registered vaults
     * @return The number of registered vaults
     */
    function getRegisteredVaultsCount() external view returns (uint256) {
        return registeredVaults.length;
    }

    /**
     * @notice Gets all registered vault addresses
     * @return Array of registered vault addresses
     */
    function getRegisteredVaults() external view returns (address[] memory) {
        return registeredVaults;
    }

    /**
     * @notice Checks if a user is ready for profit fee collection
     * @param vault The vault address
     * @param user The user address to check
     * @return True if the user is ready for collection
     */
    function isUserReadyForCollection(address vault, address user) external view returns (bool) {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            return false;
        }

        UserInfo storage userInfoStorage = userInfo[vault][user];
        if (!userInfoStorage.isRegistered) {
            return false;
        }

        return block.timestamp >= userInfoStorage.lastCollectionTime + vaultInfo.collectionInterval;
    }

    /**
     * @notice Gets the time until next collection for a user
     * @param vault The vault address
     * @param user The user address
     * @return Time in seconds until next collection (0 if ready)
     */
    function getTimeUntilNextCollection(address vault, address user) external view returns (uint256) {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            return 0;
        }

        UserInfo storage userInfoStorage = userInfo[vault][user];
        if (!userInfoStorage.isRegistered) {
            return 0;
        }

        uint256 nextCollectionTime = userInfoStorage.lastCollectionTime + vaultInfo.collectionInterval;
        if (block.timestamp >= nextCollectionTime) {
            return 0;
        }
        return nextCollectionTime - block.timestamp;
    }

    /**
     * @notice Gets vault information
     * @param vault The vault address
     * @return VaultInfo struct with vault details
     */
    function getVaultInfo(address vault) external view returns (VaultInfo memory) {
        return vaults[vault];
    }

    /**
     * @notice Gets user information
     * @param vault The vault address
     * @param user The user address
     * @return UserInfo struct with user details
     */
    function getUserInfo(address vault, address user) external view returns (UserInfo memory) {
        return userInfo[vault][user];
    }

    /**
     * @notice Calculates the potential profit fee for a user
     * @param vault The vault address
     * @param user The user address
     * @return profit The profit amount in assets
     * @return fee The fee amount in assets
     */
    function calculateProfitFee(address vault, address user) external view returns (uint256 profit, uint256 fee) {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            return (0, 0);
        }

        UserInfo storage userInfoStorage = userInfo[vault][user];
        if (!userInfoStorage.isRegistered) {
            return (0, 0);
        }

        IVault vaultContract = IVault(vault);
        uint256 currentShares = vaultContract.balanceOf(user);
        
        if (currentShares <= userInfoStorage.lastShares) {
            return (0, 0);
        }

        uint256 profitShares = currentShares - userInfoStorage.lastShares;
        profit = vaultContract.convertToAssets(profitShares);
        fee = (profit * vaultInfo.feePercent) / BASIS_POINTS;

        return (profit, fee);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IWeeklyProfitFeeCollector
 * @dev Interface for weekly profit fee collection from vault users
 */
interface IWeeklyProfitFeeCollector {
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
     * @dev Events
     */
    event VaultRegistered(address indexed vault, uint256 feePercent);
    event VaultUnregistered(address indexed vault);
    event UserRegistered(address indexed vault, address indexed user, uint256 initialShares);
    event ProfitFeeCollected(address indexed vault, address indexed user, uint256 profit, uint256 fee);
    event FeePercentUpdated(address indexed vault, uint256 newFeePercent);
    event TreasuryUpdated(address indexed newTreasury);

    /**
     * @notice Registers a vault for weekly profit fee collection
     * @param vault The vault address to register
     * @param feePercent The fee percentage in basis points (2500 = 25%)
     */
    function registerVault(address vault, uint256 feePercent) external;

    /**
     * @notice Unregisters a vault from profit fee collection
     * @param vault The vault address to unregister
     */
    function unregisterVault(address vault) external;

    /**
     * @notice Updates the fee percentage for a vault
     * @param vault The vault address
     * @param newFeePercent The new fee percentage in basis points
     */
    function updateFeePercent(address vault, uint256 newFeePercent) external;

    /**
     * @notice Registers a user for profit tracking
     * @param vault The vault address
     * @param user The user address to register
     */
    function registerUser(address vault, address user) external;

    /**
     * @notice Collects profit fees from a specific user
     * @param vault The vault address
     * @param user The user address to collect fees from
     */
    function collectUserProfitFees(address vault, address user) external;

    /**
     * @notice Collects profit fees from all registered users in a vault
     * @param vault The vault address
     */
    function collectAllUserProfitFees(address vault) external;

    /**
     * @notice Sets the treasury address
     * @param _treasury The new treasury address
     */
    function setTreasury(address _treasury) external;

    /**
     * @notice Gets the number of registered vaults
     * @return The number of registered vaults
     */
    function getRegisteredVaultsCount() external view returns (uint256);

    /**
     * @notice Gets all registered vault addresses
     * @return Array of registered vault addresses
     */
    function getRegisteredVaults() external view returns (address[] memory);

    /**
     * @notice Checks if a user is ready for profit fee collection
     * @param vault The vault address
     * @param user The user address to check
     * @return True if the user is ready for collection
     */
    function isUserReadyForCollection(address vault, address user) external view returns (bool);

    /**
     * @notice Gets the time until next collection for a user
     * @param vault The vault address
     * @param user The user address
     * @return Time in seconds until next collection (0 if ready)
     */
    function getTimeUntilNextCollection(address vault, address user) external view returns (uint256);

    /**
     * @notice Gets vault information
     * @param vault The vault address
     * @return VaultInfo struct with vault details
     */
    function getVaultInfo(address vault) external view returns (VaultInfo memory);

    /**
     * @notice Gets user information
     * @param vault The vault address
     * @param user The user address
     * @return UserInfo struct with user details
     */
    function getUserInfo(address vault, address user) external view returns (UserInfo memory);

    /**
     * @notice Calculates the potential profit fee for a user
     * @param vault The vault address
     * @param user The user address
     * @return profit The profit amount in assets
     * @return fee The fee amount in assets
     */
    function calculateProfitFee(address vault, address user) external view returns (uint256 profit, uint256 fee);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IFeeCollector
 * @dev Interface for automatic fee collection from vaults
 */
interface IFeeCollector {
    /**
     * @dev Struct to store vault collection information
     */
    struct VaultInfo {
        bool isRegistered;
        uint256 lastCollectionTime;
        uint256 collectionInterval; // in seconds
        uint256 totalFeesCollected;
    }

    /**
     * @dev Events
     */
    event VaultRegistered(address indexed vault, uint256 collectionInterval);
    event VaultUnregistered(address indexed vault);
    event FeesCollected(address indexed vault, address indexed asset, uint256 amount);
    event CollectionIntervalUpdated(address indexed vault, uint256 newInterval);
    event TreasuryUpdated(address indexed newTreasury);

    /**
     * @notice Registers a vault for automatic fee collection
     * @param vault The vault address to register
     * @param collectionInterval The interval between collections in seconds
     */
    function registerVault(address vault, uint256 collectionInterval) external;

    /**
     * @notice Unregisters a vault from automatic fee collection
     * @param vault The vault address to unregister
     */
    function unregisterVault(address vault) external;

    /**
     * @notice Updates the collection interval for a vault
     * @param vault The vault address
     * @param newInterval The new collection interval in seconds
     */
    function updateCollectionInterval(address vault, uint256 newInterval) external;

    /**
     * @notice Collects fees from a specific vault
     * @param vault The vault address to collect fees from
     */
    function collectFees(address vault) external;

    /**
     * @notice Collects fees from all registered vaults that are ready
     */
    function collectAllFees() external;

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
     * @notice Checks if a vault is ready for fee collection
     * @param vault The vault address to check
     * @return True if the vault is ready for collection
     */
    function isVaultReadyForCollection(address vault) external view returns (bool);

    /**
     * @notice Gets the time until next collection for a vault
     * @param vault The vault address
     * @return Time in seconds until next collection (0 if ready)
     */
    function getTimeUntilNextCollection(address vault) external view returns (uint256);

    /**
     * @notice Gets vault information
     * @param vault The vault address
     * @return VaultInfo struct with vault details
     */
    function getVaultInfo(address vault) external view returns (VaultInfo memory);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessManager} from "./access/AccessManager.sol";
import {IVault} from "./interfaces/IVault.sol";

/**
 * @title FeeCollector
 * @dev Automatically collects protocol fees from vaults on a scheduled basis
 */
contract FeeCollector is AccessManager {
    using SafeERC20 for IERC20;

    /**
     * @dev Errors
     */
    error FeeCollector__InvalidVault();
    error FeeCollector__InvalidInterval();
    error FeeCollector__NotEnoughTimePassed();
    error FeeCollector__NoFeesToCollect();
    error FeeCollector__TransferFailed();

    /**
     * @dev Events
     */
    event VaultRegistered(address indexed vault, uint256 collectionInterval);
    event VaultUnregistered(address indexed vault);
    event FeesCollected(address indexed vault, address indexed asset, uint256 amount);
    event CollectionIntervalUpdated(address indexed vault, uint256 newInterval);
    event TreasuryUpdated(address indexed newTreasury);

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
     * @dev State variables
     */
    address public treasury;
    mapping(address => VaultInfo) public vaults;
    address[] public registeredVaults;

    /**
     * @dev Constants
     */
    uint256 public constant MIN_COLLECTION_INTERVAL = 1 days; // Minimum 1 day
    uint256 public constant MAX_COLLECTION_INTERVAL = 30 days; // Maximum 30 days

    /**
     * @dev Constructor
     * @param _treasury The treasury address to collect fees to
     */
    constructor(address _treasury) {
        if (_treasury == address(0)) {
            revert FeeCollector__InvalidVault();
        }
        treasury = _treasury;
    }

    /**
     * @notice Registers a vault for automatic fee collection
     * @param vault The vault address to register
     * @param collectionInterval The interval between collections in seconds
     */
    function registerVault(address vault, uint256 collectionInterval) external onlyAdmin {
        if (vault == address(0)) {
            revert FeeCollector__InvalidVault();
        }
        if (collectionInterval < MIN_COLLECTION_INTERVAL || collectionInterval > MAX_COLLECTION_INTERVAL) {
            revert FeeCollector__InvalidInterval();
        }

        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            registeredVaults.push(vault);
        }

        vaultInfo.isRegistered = true;
        vaultInfo.collectionInterval = collectionInterval;
        vaultInfo.lastCollectionTime = block.timestamp;

        emit VaultRegistered(vault, collectionInterval);
    }

    /**
     * @notice Unregisters a vault from automatic fee collection
     * @param vault The vault address to unregister
     */
    function unregisterVault(address vault) external onlyAdmin {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert FeeCollector__InvalidVault();
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
     * @notice Updates the collection interval for a vault
     * @param vault The vault address
     * @param newInterval The new collection interval in seconds
     */
    function updateCollectionInterval(address vault, uint256 newInterval) external onlyAdmin {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert FeeCollector__InvalidVault();
        }
        if (newInterval < MIN_COLLECTION_INTERVAL || newInterval > MAX_COLLECTION_INTERVAL) {
            revert FeeCollector__InvalidInterval();
        }

        vaultInfo.collectionInterval = newInterval;
        emit CollectionIntervalUpdated(vault, newInterval);
    }

    /**
     * @notice Collects fees from a specific vault
     * @param vault The vault address to collect fees from
     */
    function collectFees(address vault) external {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            revert FeeCollector__InvalidVault();
        }

        if (block.timestamp < vaultInfo.lastCollectionTime + vaultInfo.collectionInterval) {
            revert FeeCollector__NotEnoughTimePassed();
        }

        IVault vaultContract = IVault(vault);
        address asset = vaultContract.asset();
        uint256 balance = IERC20(asset).balanceOf(vault);

        if (balance == 0) {
            revert FeeCollector__NoFeesToCollect();
        }

        // Transfer fees to treasury
        IERC20(asset).safeTransferFrom(vault, treasury, balance);

        // Update vault info
        vaultInfo.lastCollectionTime = block.timestamp;
        vaultInfo.totalFeesCollected += balance;

        emit FeesCollected(vault, asset, balance);
    }

    /**
     * @notice Collects fees from all registered vaults that are ready
     */
    function collectAllFees() external {
        for (uint256 i = 0; i < registeredVaults.length; i++) {
            address vault = registeredVaults[i];
            VaultInfo storage vaultInfo = vaults[vault];
            
            if (vaultInfo.isRegistered && 
                block.timestamp >= vaultInfo.lastCollectionTime + vaultInfo.collectionInterval) {
                
                try this.collectFees(vault) {
                    // Successfully collected fees
                } catch {
                    // Skip this vault if collection fails
                    continue;
                }
            }
        }
    }

    /**
     * @notice Sets the treasury address
     * @param _treasury The new treasury address
     */
    function setTreasury(address _treasury) external onlyAdmin {
        if (_treasury == address(0)) {
            revert FeeCollector__InvalidVault();
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
     * @notice Checks if a vault is ready for fee collection
     * @param vault The vault address to check
     * @return True if the vault is ready for collection
     */
    function isVaultReadyForCollection(address vault) external view returns (bool) {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            return false;
        }
        return block.timestamp >= vaultInfo.lastCollectionTime + vaultInfo.collectionInterval;
    }

    /**
     * @notice Gets the time until next collection for a vault
     * @param vault The vault address
     * @return Time in seconds until next collection (0 if ready)
     */
    function getTimeUntilNextCollection(address vault) external view returns (uint256) {
        VaultInfo storage vaultInfo = vaults[vault];
        if (!vaultInfo.isRegistered) {
            return 0;
        }

        uint256 nextCollectionTime = vaultInfo.lastCollectionTime + vaultInfo.collectionInterval;
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
}

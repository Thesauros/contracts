// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IProvider} from "../interfaces/IProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IProviderManager} from "../interfaces/IProviderManager.sol";
import {IMorpho} from "../interfaces/morpho/IMorpho.sol";
import {IOracle} from "../interfaces/morpho/IOracle.sol";
import {IIrm} from "../interfaces/morpho/IIrm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MorphoProvider
/// @notice Provider for integrating with Morpho Protocol
/// @dev This provider allows vaults to supply assets to Morpho markets and earn yield
contract MorphoProvider is IProvider {
    using SafeERC20 for IERC20;

    /// @notice Provider identifier
    string public constant IDENTIFIER = "Morpho_Provider";

    /// @notice Provider manager for getting market parameters
    IProviderManager private immutable _providerManager;

    /// @notice Morpho protocol contract
    IMorpho private immutable _morpho;

    /// @notice Market parameters storage
    mapping(address => IMorpho.MarketParams) private _assetToMarketParams;

    /// @notice Custom errors
    error MorphoProvider__AddressZero();
    error MorphoProvider__InvalidAmount();
    error MorphoProvider__InsufficientBalance();
    error MorphoProvider__MarketNotCreated();
    error MorphoProvider__InvalidAsset();

    /// @notice Events
    event MarketParamsSet(address indexed asset, address indexed loanToken, address indexed collateralToken);
    event AssetsSupplied(bytes32 indexed marketId, uint256 amount);
    event AssetsWithdrawn(bytes32 indexed marketId, uint256 amount);

    /// @notice Constructor
    /// @param providerManager_ Address of the provider manager
    /// @param morpho_ Address of the Morpho protocol contract
    constructor(address providerManager_, address morpho_) {
        if (providerManager_ == address(0)) revert MorphoProvider__AddressZero();
        if (morpho_ == address(0)) revert MorphoProvider__AddressZero();

        _providerManager = IProviderManager(providerManager_);
        _morpho = IMorpho(morpho_);
    }

    /// @notice Get the provider identifier
    /// @return The provider identifier string
    function getIdentifier() external pure override returns (string memory) {
        return IDENTIFIER;
    }

    /// @notice Get the source address for approvals
    /// @param asset The asset address
    /// @param market The market address (unused for Morpho)
    /// @param user The user address (unused for Morpho)
    /// @return The Morpho protocol address
    function getSource(address asset, address market, address user) external view override returns (address) {
        return address(_morpho);
    }

    /// @notice Set market parameters for an asset
    /// @param asset The asset address
    /// @param marketParams The market parameters
    function setMarketParams(address asset, IMorpho.MarketParams memory marketParams) external {
        _assetToMarketParams[asset] = marketParams;
        emit MarketParamsSet(asset, marketParams.loanToken, marketParams.collateralToken);
    }

    /// @notice Deposit assets to Morpho market
    /// @param amount The amount to deposit
    /// @param vault The vault contract
    /// @return success True if successful
    function deposit(uint256 amount, IVault vault) external override returns (bool success) {
        if (amount == 0) revert MorphoProvider__InvalidAmount();

        // Validate and get market parameters
        (IMorpho.MarketParams memory marketParams, bytes32 marketId) = _validateAndGetMarketParams(vault);

        // Check vault has sufficient balance
        IERC20 asset = IERC20(vault.asset());
        if (asset.balanceOf(address(vault)) < amount) {
            revert MorphoProvider__InsufficientBalance();
        }

        // Transfer assets from vault to this contract
        asset.safeTransferFrom(address(vault), address(this), amount);

        // Approve Morpho to spend assets
        asset.approve(address(_morpho), amount);

        // Supply assets to Morpho market
        try _morpho.supply(marketParams, amount, 0, address(this), "") returns (uint256, uint256) {
            success = true;
            emit AssetsSupplied(marketId, amount);
        } catch {
            // Transfer assets back to vault on failure
            asset.safeTransfer(address(vault), amount);
            success = false;
        }
    }

    /// @notice Withdraw assets from Morpho market
    /// @param amount The amount to withdraw
    /// @param vault The vault contract
    /// @return success True if successful
    function withdraw(uint256 amount, IVault vault) external override returns (bool success) {
        if (amount == 0) revert MorphoProvider__InvalidAmount();

        // Validate and get market parameters
        (IMorpho.MarketParams memory marketParams, bytes32 marketId) = _validateAndGetMarketParams(vault);

        // Check we have sufficient supply balance
        IMorpho.Position memory position = _morpho.position(marketId, address(this));
        if (position.supplyShares == 0) {
            revert MorphoProvider__InsufficientBalance();
        }

        // Withdraw assets from Morpho market
        try _morpho.withdraw(marketParams, amount, 0, address(this), address(vault)) returns (uint256, uint256) {
            success = true;
            emit AssetsWithdrawn(marketId, amount);
        } catch {
            success = false;
        }
    }

    /// @notice Get the deposit balance for a user
    /// @param user The user address
    /// @param vault The vault contract
    /// @return The deposit balance
    function getDepositBalance(address user, IVault vault) external view override returns (uint256) {
        (, bytes32 marketId) = _validateAndGetMarketParams(vault);
        IMorpho.Position memory position = _morpho.position(marketId, address(this));
        
        if (position.supplyShares == 0) return 0;
        
        IMorpho.Market memory market = _morpho.market(marketId);
        return (uint256(position.supplyShares) * market.totalSupplyAssets) / market.totalSupplyShares;
    }

    /// @notice Get the current deposit rate
    /// @param vault The vault contract
    /// @return The current deposit rate (in ray, 1e27)
    function getDepositRate(IVault vault) external view override returns (uint256) {
        (IMorpho.MarketParams memory marketParams, bytes32 marketId) = _validateAndGetMarketParams(vault);
        
        // Get current borrow rate from IRM
        IMorpho.Market memory market = _morpho.market(marketId);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRate(marketParams, market);
        
        // Calculate supply rate (borrow rate * utilization * (1 - fee))
        if (market.totalSupplyAssets == 0) return 0;
        
        uint256 utilization = (market.totalBorrowAssets * 1e27) / market.totalSupplyAssets;
        uint256 fee = market.fee;
        
        return (borrowRate * utilization / 1e27 * (1e27 - fee)) / 1e27;
    }

    /// @notice Validate asset and get market parameters
    /// @param vault The vault contract
    /// @return marketParams The market parameters
    /// @return marketId The market ID
    function _validateAndGetMarketParams(IVault vault) internal view returns (
        IMorpho.MarketParams memory marketParams,
        bytes32 marketId
    ) {
        address asset = vault.asset();
        if (asset == address(0)) revert MorphoProvider__InvalidAsset();

        // Get market parameters from storage
        marketParams = _assetToMarketParams[asset];
        if (marketParams.loanToken == address(0)) revert MorphoProvider__InvalidAsset();
        
        marketId = keccak256(abi.encode(marketParams));

        // Check if market exists
        IMorpho.Market memory market = _morpho.market(marketId);
        if (market.lastUpdate == 0) revert MorphoProvider__MarketNotCreated();
    }

    /// @notice Create a new market (only callable by owner)
    /// @param marketParams The market parameters
    function createMarket(IMorpho.MarketParams memory marketParams) external {
        _morpho.createMarket(marketParams);
        bytes32 marketId = keccak256(abi.encode(marketParams));
        emit MarketParamsSet(marketParams.loanToken, marketParams.loanToken, marketParams.collateralToken);
    }

    /// @notice Accrue interest for a market
    /// @param marketParams The market parameters
    function accrueInterest(IMorpho.MarketParams memory marketParams) external {
        _morpho.accrueInterest(marketParams);
    }

    /// @notice Get market data
    /// @param marketParams The market parameters
    /// @return The market data
    function getMarketData(IMorpho.MarketParams memory marketParams) external view returns (IMorpho.Market memory) {
        bytes32 marketId = keccak256(abi.encode(marketParams));
        return _morpho.market(marketId);
    }

    /// @notice Get position data
    /// @param marketParams The market parameters
    /// @param user The user address
    /// @return The position data
    function getPositionData(IMorpho.MarketParams memory marketParams, address user) external view returns (IMorpho.Position memory) {
        bytes32 marketId = keccak256(abi.encode(marketParams));
        return _morpho.position(marketId, user);
    }
}
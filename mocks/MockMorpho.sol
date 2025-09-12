// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IMorpho} from "../interfaces/morpho/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockMorpho
/// @notice Mock implementation of Morpho Protocol for testing
contract MockMorpho is IMorpho {
    using SafeERC20 for IERC20;

    /// @notice Market data storage
    mapping(bytes32 => Market) private _market;
    mapping(bytes32 => mapping(address => Position)) private _position;
    mapping(bytes32 => MarketParams) private _idToMarketParams;

    /// @notice Events
    event Supply(bytes32 indexed id, address indexed onBehalf, uint256 assets, uint256 shares);
    event Withdraw(bytes32 indexed id, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares);
    event Borrow(bytes32 indexed id, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares);
    event Repay(bytes32 indexed id, address indexed onBehalf, uint256 assets, uint256 shares);
    event SupplyCollateral(bytes32 indexed id, address indexed onBehalf, uint256 assets);
    event WithdrawCollateral(bytes32 indexed id, address indexed onBehalf, address indexed receiver, uint256 assets);

    /// @notice Create a new market
    function createMarket(MarketParams memory marketParams) external override {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate == 0, "Market already exists");
        
        _market[id].lastUpdate = uint128(block.timestamp);
        _idToMarketParams[id] = marketParams;
    }

    /// @notice Supply assets to a market
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external override returns (uint256, uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(assets > 0, "Invalid assets");

        // Transfer assets from caller
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        // Calculate shares if not provided
        if (shares == 0) {
            shares = _market[id].totalSupplyShares == 0 ? assets : (assets * _market[id].totalSupplyShares) / _market[id].totalSupplyAssets;
        }

        // Update market state
        _market[id].totalSupplyAssets += uint128(assets);
        _market[id].totalSupplyShares += uint128(shares);

        // Update position
        _position[id][onBehalf].supplyShares += uint128(shares);

        emit Supply(id, onBehalf, assets, shares);
        return (assets, shares);
    }

    /// @notice Withdraw assets from a market
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override returns (uint256, uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(_position[id][onBehalf].supplyShares >= shares, "Insufficient shares");

        // Calculate assets if not provided
        if (assets == 0) {
            assets = (shares * _market[id].totalSupplyAssets) / _market[id].totalSupplyShares;
        }

        // Update market state
        _market[id].totalSupplyAssets -= uint128(assets);
        _market[id].totalSupplyShares -= uint128(shares);

        // Update position
        _position[id][onBehalf].supplyShares -= uint128(shares);

        // Transfer assets to receiver
        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        emit Withdraw(id, onBehalf, receiver, assets, shares);
        return (assets, shares);
    }

    /// @notice Borrow assets from a market
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external override returns (uint256, uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(assets > 0, "Invalid assets");

        // Calculate shares if not provided
        if (shares == 0) {
            shares = _market[id].totalBorrowShares == 0 ? assets : (assets * _market[id].totalBorrowShares) / _market[id].totalBorrowAssets;
        }

        // Update market state
        _market[id].totalBorrowAssets += uint128(assets);
        _market[id].totalBorrowShares += uint128(shares);

        // Update position
        _position[id][onBehalf].borrowShares += uint128(shares);

        // Transfer assets to receiver
        IERC20(marketParams.loanToken).safeTransfer(receiver, assets);

        emit Borrow(id, onBehalf, receiver, assets, shares);
        return (assets, shares);
    }

    /// @notice Repay borrowed assets
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external override returns (uint256, uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(_position[id][onBehalf].borrowShares >= shares, "Insufficient borrow shares");

        // Calculate assets if not provided
        if (assets == 0) {
            assets = (shares * _market[id].totalBorrowAssets) / _market[id].totalBorrowShares;
        }

        // Transfer assets from caller
        IERC20(marketParams.loanToken).safeTransferFrom(msg.sender, address(this), assets);

        // Update market state
        _market[id].totalBorrowAssets -= uint128(assets);
        _market[id].totalBorrowShares -= uint128(shares);

        // Update position
        _position[id][onBehalf].borrowShares -= uint128(shares);

        emit Repay(id, onBehalf, assets, shares);
        return (assets, shares);
    }

    /// @notice Supply collateral to a market
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external override returns (uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(assets > 0, "Invalid assets");

        // Transfer collateral from caller
        IERC20(marketParams.collateralToken).safeTransferFrom(msg.sender, address(this), assets);

        // Update position
        _position[id][onBehalf].collateral += uint128(assets);

        emit SupplyCollateral(id, onBehalf, assets);
        return assets;
    }

    /// @notice Withdraw collateral from a market
    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external override returns (uint256) {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        require(_position[id][onBehalf].collateral >= assets, "Insufficient collateral");

        // Update position
        _position[id][onBehalf].collateral -= uint128(assets);

        // Transfer collateral to receiver
        IERC20(marketParams.collateralToken).safeTransfer(receiver, assets);

        emit WithdrawCollateral(id, onBehalf, receiver, assets);
        return assets;
    }

    /// @notice Accrue interest for a market
    function accrueInterest(MarketParams memory marketParams) external override {
        bytes32 id = keccak256(abi.encode(marketParams));
        require(_market[id].lastUpdate != 0, "Market not created");
        
        // Simple interest accrual (1% per block for testing)
        uint256 interest = _market[id].totalBorrowAssets * 1 / 100;
        _market[id].totalBorrowAssets += uint128(interest);
        _market[id].totalSupplyAssets += uint128(interest);
        _market[id].lastUpdate = uint128(block.timestamp);
    }

    /// @notice Get market data
    function market(bytes32 id) external view override returns (Market memory) {
        return _market[id];
    }

    /// @notice Get position data
    function position(bytes32 id, address user) external view override returns (Position memory) {
        return _position[id][user];
    }

    /// @notice Get market parameters
    function idToMarketParams(bytes32 id) external view override returns (MarketParams memory) {
        return _idToMarketParams[id];
    }
}

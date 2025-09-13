// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title IMorpho
/// @notice Interface for Morpho Protocol
interface IMorpho {
    /// @notice Market parameters
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    /// @notice Market data
    struct Market {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }

    /// @notice Position data
    struct Position {
        uint128 supplyShares;
        uint128 borrowShares;
        uint128 collateral;
    }

    /// @notice Supply assets to a market
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    /// @notice Withdraw assets from a market
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    /// @notice Borrow assets from a market
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    /// @notice Repay borrowed assets
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256, uint256);

    /// @notice Supply collateral to a market
    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes calldata data
    ) external returns (uint256);

    /// @notice Withdraw collateral from a market
    function withdrawCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external returns (uint256);

    /// @notice Get market data
    function market(bytes32 id) external view returns (Market memory);

    /// @notice Get position data
    function position(bytes32 id, address user) external view returns (Position memory);

    /// @notice Get market parameters
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);

    /// @notice Create a new market
    function createMarket(MarketParams memory marketParams) external;

    /// @notice Accrue interest for a market
    function accrueInterest(MarketParams memory marketParams) external;
}

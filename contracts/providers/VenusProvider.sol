// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ComptrollerInterface} from "../interfaces/venus/ComptrollerInterface.sol";
import {IVToken} from "../interfaces/venus/IVToken.sol";
import {LibVenus} from "../libraries/venus/LibVenus.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IProviderManager} from "../interfaces/IProviderManager.sol";
import {IProvider} from "../interfaces/IProvider.sol";

/**
 * @title VenusProvider
 */
contract VenusProvider is IProvider {
    /**
     * @dev Errors
     */
    error VenusProvider__AddressZero();

    IProviderManager private immutable _providerManager;

    constructor(address providerManager_) {
        if (providerManager_ == address(0)) {
            revert VenusProvider__AddressZero();
        }
        _providerManager = IProviderManager(providerManager_);
    }

    /**
     * @inheritdoc IProvider
     */
    function deposit(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        address asset = vault.asset();
        address vTokenAddress = _getVToken(asset);

        _enterMarket(vTokenAddress);

        IVToken vToken = IVToken(vTokenAddress);
        vToken.mint(amount);

        success = true;
    }

    /**
     * @inheritdoc IProvider
     */
    function withdraw(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        address asset = vault.asset();
        address vTokenAddress = _getVToken(asset);

        IVToken vToken = IVToken(vTokenAddress);
        vToken.redeemUnderlying(amount);

        success = true;
    }

    /**
     * @dev Adds assets to be included in the account's liquidity calculation.
     * @param vTokenAddress The address of the vToken market to be enabled
     */
    function _enterMarket(address vTokenAddress) internal {
        ComptrollerInterface comptroller = ComptrollerInterface(
            _getComptroller()
        );

        address[] memory vTokenMarkets = new address[](1);
        vTokenMarkets[0] = vTokenAddress;
        comptroller.enterMarkets(vTokenMarkets);
    }

    /**
     * @dev Returns the vToken address for the specified asset.
     */
    function _getVToken(address asset) internal view returns (address vToken) {
        vToken = _providerManager.getYieldToken(getIdentifier(), asset);
    }

    /**
     * @dev Returns the Comptroller address of Venus.
     */
    function _getComptroller() internal pure returns (address) {
        return 0x317c1A5739F39046E20b08ac9BeEa3f10fD43326;
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositBalance(
        address user,
        IVault vault
    ) external view override returns (uint256 balance) {
        address asset = vault.asset();
        IVToken vToken = IVToken(_getVToken(asset));

        balance = LibVenus.viewUnderlyingBalanceOf(vToken, user);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositRate(
        IVault vault
    ) external view override returns (uint256 rate) {
        address asset = vault.asset();
        IVToken vToken = IVToken(_getVToken(asset));

        // The number of blocks/seconds per year that is assumed by the interest rate model of Venus.
        uint256 blocksOrSecondsPerYear = vToken.blocksOrSecondsPerYear();

        // Scaled by 1e9 to return ray(1e27) per IProvider specs, Venus uses base 1e18 number.
        uint256 sRatePerBlock = vToken.supplyRatePerBlock() * 10 ** 9;

        rate = sRatePerBlock * blocksOrSecondsPerYear;
    }

    /**
     * @inheritdoc IProvider
     */
    function getSource(
        address asset,
        address,
        address
    ) external view override returns (address source) {
        source = _getVToken(asset);
    }

    /**
     * @notice Returns the ProviderManager contract applicable to this provider.
     */
    function getProviderManager() public view returns (IProviderManager) {
        return _providerManager;
    }

    /**
     * @inheritdoc IProvider
     */
    function getIdentifier() public pure override returns (string memory) {
        return "Venus_Provider";
    }
}

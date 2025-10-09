// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IProvider} from "../interfaces/IProvider.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IDepositWithdrawalProxy} from "../interfaces/dolomite/IDepositWithdrawalProxy.sol";
import {IDolomiteMargin} from "../interfaces/dolomite/IDolomiteMargin.sol";
import {IDolomiteGetter} from "../interfaces/dolomite/IDolomiteGetter.sol";

/**
 * @title DolomiteProvider
 */
contract DolomiteProvider is IProvider {
    /**
     * @inheritdoc IProvider
     */
    function deposit(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        IDepositWithdrawalProxy dolomite = _getDolomiteProxy();
        uint256 marketId = _getMarketId(vault.asset());
        dolomite.depositWeiIntoDefaultAccount(marketId, amount);
        success = true;
    }

    /**
     * @inheritdoc IProvider
     */
    function withdraw(
        uint256 amount,
        IVault vault
    ) external override returns (bool success) {
        IDepositWithdrawalProxy dolomite = _getDolomiteProxy();
        uint256 marketId = _getMarketId(vault.asset());
        dolomite.withdrawWeiFromDefaultAccount(
            marketId,
            amount,
            IDepositWithdrawalProxy.BalanceCheckFlag.From
        );
        success = true;
    }

    /**
     * @dev Returns the market id for the specified asset.
     */
    function _getMarketId(
        address asset
    ) internal view returns (uint256 marketId) {
        IDolomiteMargin margin = _getDolomiteMargin();
        marketId = margin.getMarketIdByTokenAddress(asset);
    }

    /**
     * @dev Returns the DolomiteMargin contract of Dolomite.
     */
    function _getDolomiteMargin() internal pure returns (IDolomiteMargin) {
        return IDolomiteMargin(0x6Bd780E7fDf01D77e4d475c821f1e7AE05409072);
    }

    /**
     * @dev Returns the SafeGettersForDolomiteMargin contract of Dolomite.
     */
    function _getDolomiteGetter() internal pure returns (IDolomiteGetter) {
        return IDolomiteGetter(0x9381942De7A66fdB4741272EaB4fc0A362F7a16a);
    }

    /**
     * @dev Returns the DepositWithdrawalProxy contract of Dolomite.
     */
    function _getDolomiteProxy()
        internal
        pure
        returns (IDepositWithdrawalProxy)
    {
        return
            IDepositWithdrawalProxy(0xAdB9D68c613df4AA363B42161E1282117C7B9594);
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositBalance(
        address user,
        IVault vault
    ) external view override returns (uint256 balance) {
        IDolomiteMargin margin = _getDolomiteMargin();
        uint256 marketId = _getMarketId(vault.asset());

        IDolomiteMargin.AccountInfo memory accountInfo = IDolomiteMargin
            .AccountInfo({owner: user, number: 0});

        IDolomiteMargin.Wei memory accountWei = margin.getAccountWei(
            accountInfo,
            marketId
        );
        balance = accountWei.value;
    }

    /**
     * @inheritdoc IProvider
     */
    function getDepositRate(
        IVault vault
    ) external view override returns (uint256 rate) {
        IDolomiteGetter getter = _getDolomiteGetter();
        IDolomiteMargin.InterestRate memory interestRate = getter
            .getMarketSupplyInterestRateApr(vault.asset());
        // Scaled by 1e9 to return ray(1e27) per IProvider specs, Dolomite uses base 1e18 number.
        rate = interestRate.value * 10 ** 9;
    }

    /**
     * @inheritdoc IProvider
     */
    function getSource(
        address,
        address,
        address
    ) external pure override returns (address source) {
        source = address(_getDolomiteMargin());
    }

    /**
     * @inheritdoc IProvider
     */
    function getIdentifier() public pure override returns (string memory) {
        return "Dolomite_Provider";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "../../contracts/interfaces/IVault.sol";
import {IProvider} from "../../contracts/interfaces/IProvider.sol";

/**
 * @title MockVault
 * @dev Mock vault for testing purposes
 */
contract MockVault is ERC20, IVault {
    IERC20 public immutable assetToken;
    
    mapping(address => uint256) public depositBalances;
    
    constructor(address _asset) ERC20("Mock Vault", "MV") {
        assetToken = IERC20(_asset);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
    
    // IVault interface implementation
    function asset() external view override returns (address) {
        return address(assetToken);
    }
    
    function totalAssets() external view override returns (uint256) {
        return assetToken.balanceOf(address(this));
    }
    
    function convertToShares(uint256 assets) external view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return assets;
        return (assets * supply) / this.totalAssets();
    }
    
    function convertToAssets(uint256 shares) external view override returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) return shares;
        return (shares * this.totalAssets()) / supply;
    }
    
    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    
    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    
    function maxWithdraw(address owner) external view override returns (uint256) {
        return this.convertToAssets(balanceOf(owner));
    }
    
    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }
    
    function previewDeposit(uint256 assets) external view override returns (uint256) {
        return this.convertToShares(assets);
    }
    
    function previewMint(uint256 shares) external view override returns (uint256) {
        return this.convertToAssets(shares);
    }
    
    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        return this.convertToShares(assets);
    }
    
    function previewRedeem(uint256 shares) external view override returns (uint256) {
        return this.convertToAssets(shares);
    }
    
    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        uint256 shares = this.previewDeposit(assets);
        assetToken.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        return shares;
    }
    
    function mint(uint256 shares, address receiver) external override returns (uint256) {
        uint256 assets = this.previewMint(shares);
        assetToken.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        return assets;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        uint256 shares = this.previewWithdraw(assets);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        assetToken.transfer(receiver, assets);
        return shares;
    }
    
    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        uint256 assets = this.previewRedeem(shares);
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        assetToken.transfer(receiver, assets);
        return assets;
    }
    
    // Additional functions for testing
    function setupVault(uint256 assets) external override {
        // Mock implementation
    }
    
    function rebalance(
        uint256,
        IProvider,
        IProvider,
        uint256,
        bool
    ) external pure override returns (bool) {
        // Mock implementation
        return true;
    }
}
